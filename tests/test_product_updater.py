import json
import sys
import importlib
import pytest
from unittest.mock import patch, MagicMock
from io import BytesIO
import os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_handler():
    path = os.path.join(BASE, "lambda", "product_updater", "lambda_function.py")
    spec = importlib.util.spec_from_file_location("lambda_function_pu", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.lambda_handler

def make_event(bucket, key):
    return {"Records": [{"s3": {"bucket": {"name": bucket}, "object": {"key": key}}}]}

SECRET = json.dumps({"host": "localhost", "dbname": "db", "username": "u", "password": "p", "port": 5432})

def make_boto_side_effect(sm, s3):
    return lambda service, **kwargs: sm if service == "secretsmanager" else s3

def test_update_price_only(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001", "price": 29.99}')}
    cur = MagicMock()
    cur.fetchone.return_value = (1,)

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        load_handler()(make_event("product-bucket", "test.json"), {})

    update_call = cur.execute.call_args_list[1]
    assert "price = %s" in update_call[0][0]
    assert "stock_quantity" not in update_call[0][0]

def test_update_stock_only(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001", "stock_quantity": 50}')}
    cur = MagicMock()
    cur.fetchone.return_value = (1,)

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        load_handler()(make_event("product-bucket", "test.json"), {})

    update_call = cur.execute.call_args_list[1]
    assert "stock_quantity = %s" in update_call[0][0]
    assert "price" not in update_call[0][0]

def test_update_both(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001", "price": 19.99, "stock_quantity": 75}')}
    cur = MagicMock()
    cur.fetchone.return_value = (1,)

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        load_handler()(make_event("product-bucket", "test.json"), {})

    update_call = cur.execute.call_args_list[1]
    assert "price = %s" in update_call[0][0]
    assert "stock_quantity = %s" in update_call[0][0]

def test_no_fields_provided(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001"}')}

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect"):
        with pytest.raises(ValueError, match="No updates provided"):
            load_handler()(make_event("product-bucket", "test.json"), {})

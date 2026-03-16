import json
import sys
import importlib
import pytest
from unittest.mock import patch, MagicMock
from io import BytesIO
import os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_handler():
    path = os.path.join(BASE, "lambda", "sales_processor", "lambda_function.py")
    spec = importlib.util.spec_from_file_location("lambda_function_sp", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.lambda_handler

def make_event(bucket, key):
    return {"Records": [{"s3": {"bucket": {"name": bucket}, "object": {"key": key}}}]}

SECRET = json.dumps({"host": "localhost", "dbname": "db", "username": "u", "password": "p", "port": 5432})

def make_boto_side_effect(sm, s3):
    return lambda service, **kwargs: sm if service == "secretsmanager" else s3

def test_valid_sale(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001", "quantity": 2}')}
    cur = MagicMock()
    cur.fetchone.return_value = (1, 10)

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        load_handler()(make_event("sales-bucket", "test.json"), {})

    assert cur.execute.call_count == 3

def test_invalid_sku(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "INVALID", "quantity": 1}')}
    cur = MagicMock()
    cur.fetchone.return_value = None

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        with pytest.raises(ValueError, match="SKU not found"):
            load_handler()(make_event("sales-bucket", "test.json"), {})

def test_insufficient_stock(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001", "quantity": 999}')}
    cur = MagicMock()
    cur.fetchone.return_value = (1, 5)

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        with pytest.raises(ValueError, match="Insufficient stock"):
            load_handler()(make_event("sales-bucket", "test.json"), {})

def test_invalid_quantity(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    s3 = MagicMock()
    s3.get_object.return_value = {"Body": BytesIO(b'{"sku": "UNQ-001", "quantity": -1}')}

    with patch("boto3.client", side_effect=make_boto_side_effect(sm, s3)), \
         patch("pg8000.dbapi.connect"):
        with pytest.raises(ValueError, match="Invalid quantity"):
            load_handler()(make_event("sales-bucket", "test.json"), {})

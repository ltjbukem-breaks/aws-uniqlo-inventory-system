import json
import sys
import importlib
import pytest
from unittest.mock import patch, MagicMock
import os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_handler():
    path = os.path.join(BASE, "lambda", "inventory_restock", "lambda_function.py")
    spec = importlib.util.spec_from_file_location("lambda_function_ir", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.lambda_handler

SECRET = json.dumps({"host": "localhost", "dbname": "db", "username": "u", "password": "p", "port": 5432})

def test_no_restock_needed(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    cur = MagicMock()
    cur.fetchall.return_value = []

    with patch("boto3.client", return_value=sm), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        result = load_handler()({}, {})

    assert result == {"status": "ok", "message": "All stock above threshold"}
    cur.execute.assert_called_once()

def test_restock_triggered(monkeypatch):
    monkeypatch.setenv("DB_SECRET_ARN", "arn:fake")
    sm = MagicMock()
    sm.get_secret_value.return_value = {"SecretString": SECRET}
    cur = MagicMock()
    cur.fetchall.return_value = [(1, 20), (2, 35)]
    cur.fetchone.side_effect = [("UNQ-001",), ("UNQ-002",)]

    with patch("boto3.client", return_value=sm), \
         patch("pg8000.dbapi.connect") as mock_connect:
        mock_connect.return_value.cursor.return_value = cur
        load_handler()({}, {})

    assert cur.execute.call_count == 7
    mock_connect.return_value.commit.assert_called_once()

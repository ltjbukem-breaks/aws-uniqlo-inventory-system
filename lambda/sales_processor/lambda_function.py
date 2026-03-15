import json
import boto3
import pg8000.dbapi
from datetime import datetime, timezone

def get_db_connection(secret_arn):
    client = boto3.client('secretsmanager')
    secret = json.loads(client.get_secret_value(SecretId=secret_arn)['SecretString'])
    return pg8000.dbapi.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret['port'],
        ssl_context=True
    )

def lambda_handler(event, context):
    import os
    secret_arn = os.environ['DB_SECRET_ARN']
    s3 = boto3.client('s3')

    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']

    file = s3.get_object(Bucket=bucket, Key=key)
    sale = json.loads(file['Body'].read().decode('utf-8'))

    sku = sale['sku']
    quantity = sale['quantity']
    sold_at = datetime.now(timezone.utc)

    if not isinstance(quantity, int) or quantity <= 0:
        raise ValueError(f"Invalid quantity: {quantity}")

    conn = get_db_connection(secret_arn)
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, stock_quantity FROM products WHERE sku = %s", (sku,))
        product = cur.fetchone()

        if not product:
            raise ValueError(f"SKU not found: {sku}")

        product_id, stock = product

        if quantity > stock:
            raise ValueError(f"Insufficient stock: requested {quantity}, available {stock}")

        cur.execute(
            "INSERT INTO sales (product_id, quantity_sold, total_price, sold_at) VALUES (%s, %s, (SELECT price * %s FROM products WHERE id = %s), %s)",
            (product_id, quantity, quantity, product_id, sold_at)
        )
        cur.execute(
            "UPDATE products SET stock_quantity = stock_quantity - %s, updated_at = %s WHERE id = %s",
            (quantity, sold_at, product_id)
        )
        conn.commit()
    finally:
        cur.close()
        conn.close()


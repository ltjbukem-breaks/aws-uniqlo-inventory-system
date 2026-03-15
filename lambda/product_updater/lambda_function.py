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
    update = json.loads(file['Body'].read().decode('utf-8'))

    sku = update['sku']
    price = update.get('price')
    stock_quantity = update.get('stock_quantity')

    if price is None and stock_quantity is None:
        raise ValueError(f"No updates provided for SKU: {sku}")

    if price is not None and (not isinstance(price, (int, float)) or price <= 0):
        raise ValueError(f"Invalid price: {price}")

    if stock_quantity is not None and (not isinstance(stock_quantity, int) or stock_quantity < 0):
        raise ValueError(f"Invalid stock_quantity: {stock_quantity}")

    conn = get_db_connection(secret_arn)
    try:
        cur = conn.cursor()
        cur.execute("SELECT id FROM products WHERE sku = %s", (sku,))
        product = cur.fetchone()

        if not product:
            raise ValueError(f"SKU not found: {sku}")

        fields = []
        values = []

        if price is not None:
            fields.append("price = %s")
            values.append(price)

        if stock_quantity is not None:
            fields.append("stock_quantity = %s")
            values.append(stock_quantity)

        fields.append("updated_at = %s")
        values.append(datetime.now(timezone.utc))
        values.append(product[0])

        cur.execute(
            f"UPDATE products SET {', '.join(fields)} WHERE id = %s",
            values
        )
        conn.commit()
    finally:
        cur.close()
        conn.close()


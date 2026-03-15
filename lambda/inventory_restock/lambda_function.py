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

    conn = get_db_connection(secret_arn)
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, stock_quantity FROM products WHERE stock_quantity < 50")
        low_stock_products = cur.fetchall()

        if not low_stock_products:
            print("No restocking needed, all stock above threshold")
            return {"status": "ok", "message": "All stock above threshold"}

        restocked_at = datetime.now(timezone.utc)
        for product_id, current_stock in low_stock_products:
            units_added = 100 - current_stock
            cur.execute(
                "UPDATE products SET stock_quantity = 100, updated_at = %s WHERE id = %s",
                (restocked_at, product_id)
            )
            cur.execute(
                "INSERT INTO inventory_logs (product_id, units_added, triggered_by, restocked_at) VALUES (%s, %s, %s, %s)",
                (product_id, units_added, "inventory_restock_lambda", restocked_at)
            )
            cur.execute("SELECT sku FROM products WHERE id = %s", (product_id,))
            sku = cur.fetchone()[0]
            print(f"Restocked SKU {sku}: added {units_added} units at {restocked_at}")

        conn.commit()
        print(f"Total products restocked: {len(low_stock_products)}")
    finally:
        cur.close()
        conn.close()

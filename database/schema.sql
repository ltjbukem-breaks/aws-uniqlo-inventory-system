/* Schema used to create the products, sales, and inventory_logs
tables for this projecet. */

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    size VARCHAR(20),
    color VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sales (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    quantity_sold INTEGER NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    sold_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventory_logs (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    units_added INTEGER NOT NULL,
    triggered_by VARCHAR(100),
    restocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

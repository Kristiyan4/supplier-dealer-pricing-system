import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

DB_USER = os.environ.get("DB_USER", "root")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "rootpassword")
DB_HOST = os.environ.get("DB_HOST", "127.0.0.1")
DB_PORT = os.environ.get("DB_PORT", "3306")
DB_NAME = os.environ.get("DB_NAME", "supplier_dealer_system")

engine = create_engine(
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

OUTPUT_DIR = "analysis_output"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def top_selling_products():
    query = """
        SELECT p.product_name, SUM(oi.quantity) AS units_sold, SUM(oi.line_total) AS revenue
        FROM order_items oi
        JOIN orders o ON o.order_id = oi.order_id
        JOIN products p ON p.product_id = oi.product_id
        WHERE o.status IN ('CONFIRMED','COMPLETED')
        GROUP BY p.product_id, p.product_name
        ORDER BY revenue DESC
    """
    df = pd.read_sql(query, engine)
    print("\nTop selling products by revenue:")
    print(df.to_string(index=False))

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df["product_name"], df["revenue"], color="#1D9E75")
    ax.set_title("Revenue by product")
    ax.set_ylabel("Revenue (BGN)")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(f"{OUTPUT_DIR}/revenue_by_product.png", dpi=150)
    plt.close(fig)
    return df


def revenue_by_supplier():
    query = """
        SELECT s.supplier_name, SUM(oi.line_total) AS revenue
        FROM order_items oi
        JOIN orders o ON o.order_id = oi.order_id
        JOIN products p ON p.product_id = oi.product_id
        JOIN suppliers s ON s.supplier_id = p.supplier_id
        WHERE o.status IN ('CONFIRMED','COMPLETED')
        GROUP BY s.supplier_id, s.supplier_name
        ORDER BY revenue DESC
    """
    df = pd.read_sql(query, engine)
    print("\nRevenue by supplier:")
    print(df.to_string(index=False))

    fig, ax = plt.subplots(figsize=(7, 7))
    ax.pie(df["revenue"], labels=df["supplier_name"], autopct="%1.1f%%", startangle=90)
    ax.set_title("Revenue share by supplier")
    plt.tight_layout()
    fig.savefig(f"{OUTPUT_DIR}/revenue_by_supplier.png", dpi=150)
    plt.close(fig)
    return df


def price_history(product_id=1):
    query = """
        SELECT valid_from, price
        FROM product_prices
        WHERE product_id = %(product_id)s
        ORDER BY valid_from
    """
    df = pd.read_sql(query, engine, params={"product_id": product_id})
    df["valid_from"] = pd.to_datetime(df["valid_from"])

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.step(df["valid_from"], df["price"], where="post", color="#378ADD", linewidth=2)
    ax.set_title(f"Price history for product #{product_id}")
    ax.set_ylabel("Price (BGN)")
    plt.tight_layout()
    fig.savefig(f"{OUTPUT_DIR}/price_history_product_{product_id}.png", dpi=150)
    plt.close(fig)
    return df


def stock_by_category():
    query = """
        SELECT c.category_name, SUM(p.stock_qty) AS total_stock
        FROM products p
        JOIN categories c ON c.category_id = p.category_id
        GROUP BY c.category_id, c.category_name
        ORDER BY total_stock DESC
    """
    df = pd.read_sql(query, engine)
    print("\nStock by category:")
    print(df.to_string(index=False))

    fig, ax = plt.subplots(figsize=(7, 5))
    ax.barh(df["category_name"], df["total_stock"], color="#BA7517")
    ax.set_title("Total stock by category")
    ax.set_xlabel("Units in stock")
    plt.tight_layout()
    fig.savefig(f"{OUTPUT_DIR}/stock_by_category.png", dpi=150)
    plt.close(fig)
    return df


if __name__ == "__main__":
    print(f"Connecting to {DB_NAME} at {DB_HOST}:{DB_PORT} ...")
    top_selling_products()
    revenue_by_supplier()
    price_history(product_id=1)
    stock_by_category()
    print(f"\nDone. Charts saved to ./{OUTPUT_DIR}/")

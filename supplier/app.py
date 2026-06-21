import os

from dotenv import load_dotenv
from flask import Flask, jsonify, request
import mysql.connector
from mysql.connector import Error

load_dotenv()

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "127.0.0.1"),
    "port": int(os.environ.get("DB_PORT", 3306)),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", "rootpassword"),
    "database": os.environ.get("DB_NAME", "supplier_dealer_system"),
}


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/products", methods=["GET"])
def list_products():
    """Returns all active products with their current price, using the
    v_current_product_prices view already defined in schema.sql."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM v_current_product_prices ORDER BY product_name")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(rows)


@app.route("/products/<int:product_id>", methods=["GET"])
def get_product(product_id):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT * FROM v_current_product_prices WHERE product_id = %s",
        (product_id,),
    )
    row = cursor.fetchone()
    cursor.close()
    conn.close()

    if row is None:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(row)


@app.route("/products/<int:product_id>/price", methods=["PUT"])
def change_price(product_id):
    """Body: { "price": 59.90, "changed_by": "admin" }
    Calls sp_change_product_price, which closes the old price window,
    opens a new one, and writes an entry to price_change_log."""
    data = request.get_json(silent=True) or {}
    new_price = data.get("price")
    changed_by = data.get("changed_by", "api")

    if new_price is None:
        return jsonify({"error": "price is required"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.callproc("sp_change_product_price", [product_id, new_price, changed_by])
        conn.commit()
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        cursor.close()
        conn.close()

    return jsonify({
        "message": "Price updated",
        "product_id": product_id,
        "new_price": new_price,
    })


@app.route("/orders", methods=["POST"])
def create_order():
    """Body: { "dealer_id": 1, "product_id": 2, "quantity": 3 }
    Calls sp_create_order, which validates stock, applies the dealer's
    discount, and creates the order inside a transaction."""
    data = request.get_json(silent=True) or {}
    dealer_id = data.get("dealer_id")
    product_id = data.get("product_id")
    quantity = data.get("quantity")

    if not all([dealer_id, product_id, quantity]):
        return jsonify({"error": "dealer_id, product_id and quantity are required"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    order_id = None
    try:
        cursor.callproc("sp_create_order", [dealer_id, product_id, quantity])
        for result in cursor.stored_results():
            row = result.fetchone()
            if row:
                order_id = row[0]
        conn.commit()
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        cursor.close()
        conn.close()

    return jsonify({"message": "Order created", "order_id": order_id}), 201


@app.route("/dealers/<int:dealer_id>/orders", methods=["GET"])
def dealer_orders(dealer_id):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT * FROM v_dealer_order_history WHERE dealer_id = %s ORDER BY order_date DESC",
        (dealer_id,),
    )
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(rows)


@app.route("/products/top-selling", methods=["GET"])
def top_selling():
    """Query params: from, to (YYYY-MM-DD), limit (default 5)."""
    date_from = request.args.get("from", "2000-01-01")
    date_to = request.args.get("to", "2100-01-01")
    limit = int(request.args.get("limit", 5))

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.callproc("sp_top_selling_products", [date_from, date_to, limit])
    rows = []
    for result in cursor.stored_results():
        rows = result.fetchall()
    cursor.close()
    conn.close()
    return jsonify(rows)


if __name__ == "__main__":
    app.run(debug=True, port=5001)

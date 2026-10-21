"""Deterministic synthetic retail data loader for the existing PostgreSQL schema.

Run: python scripts/load_retail_data.py --mode rebuild --orders 15000 --seed 42
     python scripts/load_retail_data.py --mode incremental --orders 2000 --seed 43
     python scripts/load_retail_data.py --mode validate
"""
from __future__ import annotations

import argparse
import os
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone, date
from decimal import Decimal
from pathlib import Path

import psycopg
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / '.env')
UTC = timezone.utc
REGIONS = ('Southeast', 'South', 'Northeast', 'Central-West', 'North')
CATEGORIES = ((1,'Smartphones','Electronics'),(2,'Computers','Electronics'),(3,'Televisions','Electronics'),(4,'Kitchen','Home'),(5,'Furniture','Home'),(6,'Sportswear','Fashion'),(7,'Footwear','Fashion'),(8,'Beauty','Personal Care'))
PAYMENT_METHODS = ('CREDIT_CARD', 'DEBIT_CARD', 'PIX', 'BANK_TRANSFER')

def money(value):
    return Decimal(str(value)).quantize(Decimal('0.01'))

def connection():
    return psycopg.connect(host=os.getenv('POSTGRES_HOST', '127.0.0.1'), port=int(os.getenv('POSTGRES_PORT','5433')),
        dbname=os.getenv('POSTGRES_DB','retail_analytics'),
        user=os.getenv('POSTGRES_USER','retail_admin'),
        password=os.environ['POSTGRES_PASSWORD'], connect_timeout=10)

def insert_many(cur, table, columns, rows):
    if not rows:
        return 0
    placeholders = ','.join(['%s'] * len(columns))
    sql = f"INSERT INTO {table} ({','.join(columns)}) VALUES ({placeholders})"
    with cur.copy(f"COPY {table} ({','.join(columns)}) FROM STDIN") as cp:
        for row in rows:
            cp.write_row(row)
    return len(rows)

def count(cur, table):
    cur.execute(f'SELECT count(*) FROM {table}')
    return cur.fetchone()[0]

def validate(cur):
    tables = ('categories','channels','stores','customers','products','orders','order_items','payments','returns')
    counts = {t: count(cur, f'raw.{t}') for t in tables}
    cur.execute('''SELECT count(*) FROM raw.order_items
        WHERE line_discount_amount <> quantity * (unit_list_price - unit_selling_price)''')
    assert cur.fetchone()[0] == 0, 'Discount reconciliation failed'
    cur.execute('''SELECT count(*) FROM raw.returns r JOIN raw.order_items i USING (order_item_id)
        WHERE r.return_quantity > i.quantity''')
    assert cur.fetchone()[0] == 0, 'Return quantity exceeds purchased quantity'
    cur.execute('''SELECT count(*) FROM raw.payments p JOIN raw.orders o USING (order_id)
        WHERE p.payment_at < o.order_created_at''')
    assert cur.fetchone()[0] == 0, 'Payment chronology failed'
    print('VALIDATION PASS:', ', '.join(f'{k}={v}' for k,v in counts.items()))
    return counts

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mode', choices=('rebuild','incremental','validate'), default='rebuild')
    ap.add_argument('--orders', type=int, default=15000)
    ap.add_argument('--seed', type=int, default=42)
    args = ap.parse_args()
    if args.orders < 1 and args.mode != 'validate':
        ap.error('--orders must be positive')
    rng = random.Random(args.seed)
    now = datetime.now(UTC)
    run_id = uuid.uuid4()
    loaded = 0
    with connection() as conn:
        with conn.cursor() as cur:
            cur.execute('''INSERT INTO control.pipeline_runs
                (run_id,run_mode,started_at,run_status)
                VALUES (%s,%s,%s,'RUNNING')''', (run_id,args.mode.upper(),now))
        conn.commit()
        try:
            with conn.cursor() as cur:
                if args.mode == 'validate':
                    validate(cur)
                else:
                    if args.mode == 'rebuild':
                        # Raw operational tables only; preserve control audit history.
                        cur.execute('''TRUNCATE TABLE raw.returns, raw.payments, raw.order_items,
                            raw.orders, raw.products, raw.customers, raw.stores,
                            raw.channels, raw.categories RESTART IDENTITY CASCADE''')
                    cur.execute('SELECT COALESCE(MAX(customer_id),0) FROM raw.customers')
                    customer_base = cur.fetchone()[0]
                    cur.execute('SELECT COALESCE(MAX(order_id),0) FROM raw.orders')
                    order_base = cur.fetchone()[0]
                    cur.execute('SELECT COALESCE(MAX(order_item_id),0) FROM raw.order_items')
                    item_base = cur.fetchone()[0]
                    cur.execute('SELECT COALESCE(MAX(payment_id),0) FROM raw.payments')
                    payment_base = cur.fetchone()[0]
                    cur.execute('SELECT COALESCE(MAX(return_id),0) FROM raw.returns')
                    return_base = cur.fetchone()[0]
                    cur.execute('SELECT count(*) FROM raw.categories')
                    if cur.fetchone()[0] == 0:
                        loaded += insert_many(cur,'raw.categories',('category_id','category_name','department_name','is_active'),
                            [(i,n,d,True) for i,n,d in CATEGORIES])
                    cur.execute('SELECT count(*) FROM raw.channels')
                    if cur.fetchone()[0] == 0:
                        loaded += insert_many(cur,'raw.channels',('channel_id','channel_name','channel_group','is_active'),
                            [(1,'STORE','PHYSICAL',True),(2,'ECOMMERCE','DIGITAL',True)])
                    cur.execute('SELECT count(*) FROM raw.stores')
                    if cur.fetchone()[0] == 0:
                        loaded += insert_many(cur,'raw.stores',('store_id','store_name','store_type','region','opening_date','is_active'),
                            [(i,f'Store {i:02d}','PHYSICAL',REGIONS[(i-1)%5],date(2018,1,1),True) for i in range(1,11)]
                            + [(11,'Online Store','ONLINE','Southeast',date(2018,1,1),True)])
                    cur.execute('SELECT count(*) FROM raw.products')
                    if cur.fetchone()[0] == 0:
                        products = []
                        for i in range(1,401):
                            price = money(rng.randint(20,2500) + rng.choice((0,.50,.90)))
                            cost = money(price * Decimal(str(rng.uniform(.48,.78))))
                            products.append((i,f'SKU-{i:06d}',f'Product {i:04d}',1+(i-1)%8,price,cost,True,now))
                        loaded += insert_many(cur,'raw.products',('product_id','sku','product_name','category_id','list_price','standard_unit_cost','is_active','updated_at'),products)
                    cur.execute('SELECT product_id,list_price,standard_unit_cost FROM raw.products ORDER BY product_id')
                    product_catalog = cur.fetchall()
                    cur.execute('SELECT customer_id FROM raw.customers ORDER BY customer_id')
                    existing_customers = [r[0] for r in cur.fetchall()]
                    new_customers_count = max(200, args.orders//4) if args.mode=='rebuild' else max(50,args.orders//8)
                    new_customers = []
                    for i in range(1,new_customers_count+1):
                        cid = customer_base+i
                        created = now - timedelta(days=rng.randint(30,900))
                        new_customers.append((cid,created,rng.randint(1955,2006),rng.choice(REGIONS),
                            rng.choice(('ORGANIC','PAID_SEARCH','SOCIAL','REFERRAL')),
                            rng.choice(('NEW','REGULAR','LOYAL')),created))
                    loaded += insert_many(cur,'raw.customers',('customer_id','customer_created_at','birth_year',
                        'customer_region','acquisition_channel','customer_segment','updated_at'),new_customers)
                    customers = existing_customers + [r[0] for r in new_customers]
                    customer_created = {r[0]:r[1] for r in new_customers}
                    # Existing customers were created before this batch; use their timestamps too.
                    cur.execute('SELECT customer_id,customer_created_at FROM raw.customers')
                    customer_created.update(cur.fetchall())
                    orders=[]; items=[]; payments=[]; returns=[]
                    for i in range(1,args.orders+1):
                        oid=order_base+i
                        cid=rng.choice(customers)
                        # 24-month historical window, respecting customer creation date.
                        earliest=max(now-timedelta(days=730),customer_created[cid])
                        seconds=max(0,int((now-earliest).total_seconds()))
                        ordered=earliest+timedelta(seconds=rng.randint(0,seconds))
                        # Weekend/holiday seasonality is intentionally not simulated here.
                        online=rng.random()<.42
                        status=rng.choices(('FULFILLED','CONFIRMED','CANCELLED','CREATED'),weights=(78,12,7,3))[0]
                        orders.append((oid,cid,11 if online else rng.randint(1,10),2 if online else 1,
                            ordered,status,ordered+timedelta(minutes=10),'ECOMMERCE' if online else 'POS'))
                        order_total=Decimal('0.00')
                        n_items=rng.randint(1,4)
                        item_ids=[]
                        for _ in range(n_items):
                            iid=item_base+len(items)+1
                            pid,list_price,cost=rng.choice(product_catalog)
                            qty=rng.randint(1,3)
                            discount=rng.choice((Decimal('0'),Decimal('.05'),Decimal('.10'),Decimal('.15')))
                            selling=money(list_price*(1-discount))
                            line_discount=qty*(list_price-selling)
                            items.append((iid,oid,pid,qty,list_price,selling,cost,line_discount,ordered))
                            item_ids.append((iid,qty,selling))
                            order_total+=qty*selling
                        pay_status='APPROVED' if status in ('FULFILLED','CONFIRMED') else ('FAILED' if status=='CANCELLED' else 'PENDING')
                        payments.append((payment_base+i,oid,rng.choice(PAYMENT_METHODS),pay_status,
                            order_total,ordered+timedelta(minutes=5),ordered+timedelta(minutes=5)))
                        if status=='FULFILLED' and rng.random()<.07:
                            iid,qty,selling=rng.choice(item_ids)
                            rqty=rng.randint(1,qty)
                            rstatus=rng.choices(('COMPLETED','REQUESTED','APPROVED','REJECTED'),weights=(65,15,10,10))[0]
                            requested=ordered+timedelta(days=rng.randint(1,20))
                            if requested>now:
                                continue
                            completed=requested+timedelta(days=2) if rstatus=='COMPLETED' else None
                            if completed and completed>now:
                                continue
                            returns.append((return_base+len(returns)+1,iid,rqty,rqty*selling,rstatus,
                                rng.choice(('DAMAGED','WRONG_SIZE','CHANGED_MIND','OTHER')),
                                requested,completed,completed or requested))
                    loaded += insert_many(cur,'raw.orders',('order_id','customer_id','store_id','channel_id','order_created_at','order_status','order_updated_at','source_system'),orders)
                    loaded += insert_many(cur,'raw.order_items',('order_item_id','order_id','product_id','quantity','unit_list_price','unit_selling_price','unit_cost','line_discount_amount','created_at'),items)
                    loaded += insert_many(cur,'raw.payments',('payment_id','order_id','payment_method','payment_status','payment_amount','payment_at','updated_at'),payments)
                    loaded += insert_many(cur,'raw.returns',('return_id','order_item_id','return_quantity','return_amount','return_status','return_reason','requested_at','completed_at','updated_at'),returns)
                    validate(cur)
            conn.commit()
            with conn.cursor() as cur:
                cur.execute('''UPDATE control.pipeline_runs SET finished_at=%s,run_status='SUCCESS',records_loaded=%s
                    WHERE run_id=%s''',(datetime.now(UTC),loaded,run_id))
            conn.commit()
            print(f'PIPELINE SUCCESS: run_id={run_id}, loaded={loaded}, mode={args.mode}')
        except Exception as exc:
            conn.rollback()
            with conn.cursor() as cur:
                cur.execute('''UPDATE control.pipeline_runs SET finished_at=%s,run_status='FAILED',error_message=%s
                    WHERE run_id=%s''',(datetime.now(UTC),str(exc)[:4000],run_id))
            conn.commit()
            print(f'PIPELINE FAILED: {exc}',file=sys.stderr)
            raise

if __name__ == '__main__':
    main()

-- ============================================================
-- Анализ сезонности продаж: очистка данных и агрегация
-- ============================================================

-- ---------- 1. Создание таблиц ----------

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    category VARCHAR(50),
    product_name VARCHAR(100),
    base_price NUMERIC
);

CREATE TABLE sales (
    order_id INTEGER,
    order_date DATE,
    product_id INTEGER,
    quantity INTEGER,
    price NUMERIC,
    region VARCHAR(50),
    marketplace VARCHAR(50),
    status VARCHAR(50)
);

-- После создания таблиц данные из products.csv и sales.csv
-- загружены через мастер импорта DBeaver (правый клик по таблице -> Импорт данных).


-- ---------- 2. Разведочный анализ: поиск некорректных записей ----------

-- пропущенный product_id
SELECT * FROM sales WHERE product_id IS NULL;

-- отрицательное количество
SELECT * FROM sales WHERE quantity < 0;

-- нулевая цена
SELECT * FROM sales WHERE price = 0;

-- пропущенный регион (стандартная проверка на NULL)
SELECT * FROM sales WHERE region IS NULL;

-- пропущенный регион, записанный как пустая строка, а не NULL
-- (стандартная проверка выше эти строки не находит)
SELECT * FROM sales WHERE region = '';

-- даты за пределами периода теста (2024 год)
SELECT * FROM sales WHERE order_date < '2024-01-01' OR order_date > '2024-12-31';

-- полные дубликаты строк
SELECT order_id, order_date, product_id, quantity, price, region, marketplace, status, COUNT(*)
FROM sales
GROUP BY order_id, order_date, product_id, quantity, price, region, marketplace, status
HAVING COUNT(*) > 1;


-- ---------- 3. Исправление "невидимых" пропусков ----------

-- пустая строка в регионе -> настоящий NULL, чтобы IS NULL находил её корректно
UPDATE sales SET region = NULL WHERE region = '';

-- проверка после исправления (должно быть 7)
SELECT COUNT(*) FROM sales WHERE region IS NULL;


-- ---------- 4. Очистка: создание чистой таблицы ----------

CREATE TABLE sales_clean AS
SELECT DISTINCT ON (order_id) *
FROM sales
WHERE product_id IS NOT NULL
  AND quantity > 0
  AND price > 0
  AND region IS NOT NULL
  AND order_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY order_id, order_date;

-- проверка количества строк после очистки
SELECT COUNT(*) FROM sales_clean;


-- ---------- 5. Агрегация: выручка и количество проданных единиц по месяцам и категориям ----------

SELECT
    EXTRACT(MONTH FROM sc.order_date) AS month,
    p.category,
    SUM(sc.quantity) AS units_sold,
    SUM(sc.quantity * sc.price) AS revenue
FROM sales_clean sc
JOIN products p ON sc.product_id = p.product_id
WHERE sc.status = 'Доставлен'
GROUP BY EXTRACT(MONTH FROM sc.order_date), p.category
ORDER BY p.category, month;

-- результат этого запроса экспортирован в monthly_category_sales.csv
-- и загружен в Power BI для построения дашборда

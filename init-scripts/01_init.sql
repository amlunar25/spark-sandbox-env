-- ─── Schema for batch pipeline practice ────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100)  NOT NULL,
    email       VARCHAR(150)  UNIQUE NOT NULL,
    country     VARCHAR(50)   NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER       NOT NULL REFERENCES users(id),
    amount      NUMERIC(10,2) NOT NULL,
    category    VARCHAR(50)   NOT NULL,
    status      VARCHAR(20)   NOT NULL DEFAULT 'completed',
    created_at  TIMESTAMP     DEFAULT NOW()
);

-- Aggregated sink written by Spark jobs
CREATE TABLE IF NOT EXISTS daily_summary (
    summary_date  DATE         NOT NULL,
    category      VARCHAR(50)  NOT NULL,
    total_amount  NUMERIC(12,2),
    tx_count      INTEGER,
    updated_at    TIMESTAMP    DEFAULT NOW(),
    PRIMARY KEY (summary_date, category)
);

-- ─── Seed data ───────────────────────────────────────────────────────────────

INSERT INTO users (name, email, country) VALUES
    ('Alice Johnson',  'alice@example.com',  'US'),
    ('Bob Smith',      'bob@example.com',    'UK'),
    ('Carlos Rivera',  'carlos@example.com', 'MX'),
    ('Diana Chen',     'diana@example.com',  'SG'),
    ('Ethan Müller',   'ethan@example.com',  'DE')
ON CONFLICT DO NOTHING;

INSERT INTO transactions (user_id, amount, category, status) VALUES
    (1, 150.00, 'electronics', 'completed'),
    (1,  25.50, 'food',        'completed'),
    (2,  89.99, 'clothing',    'completed'),
    (3, 200.00, 'electronics', 'completed'),
    (2,  12.00, 'food',        'completed'),
    (4, 340.00, 'travel',      'completed'),
    (5,  55.00, 'clothing',    'pending'),
    (1,  18.75, 'food',        'completed'),
    (3,  99.00, 'electronics', 'refunded'),
    (4,  30.00, 'food',        'completed');

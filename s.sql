-- POWERFUL PRO — BIR MARTALIK O'RNATISH: eski (kerakmas) jadvallarni o'chiradi, keyin to'liq sxemani yozadi.
-- DIQQAT: faqat birinchi o'rnatishda ishga tushiring. Ilova ishlay boshlagandan keyin QAYTA ISHLATMANG (ma'lumot o'chadi).
drop view if exists public.customer_balance cascade;
drop table if exists public.sale_items, public.customer_debts, public.cashbox, public.sales,
  public.products, public.customers, public.staff cascade;

-- ════════════════════════════════════════════════════════════════════
-- POWERFUL PRO — TO'LIQ BAZA SXEMASI (noldan o'rnatish uchun)
-- Manba: production Supabase (2026-10-01) — faqat o'qib olindi; har bir bo'lim
-- production bilan md5 orqali 1:1 solishtirilgan.
--
-- QANDAY ISHLATILADI: yangi Supabase loyiha → SQL Editor → shu faylni to'liq
-- joylab RUN. Takroriy ishga tushirish xavfsiz (if not exists / on conflict).
-- Mavjud production bazasida ISHGA TUSHIRMANG — o'rniga yangi migratsiya fayllarini
-- (supabase-migration-22/23-*.sql) qo'llang.
--
-- Eski supabase-migration-*.sql fayllari tarix uchun saqlanadi; yangi
-- o'rnatishda FAQAT shu fayl kerak.
-- ════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

-- ────────────────────────────────────────────────────────────────────
-- 1. JADVALLAR (33 ta)
-- ────────────────────────────────────────────────────────────────────
create table if not exists public.app_data (
  id text not null,
  data jsonb default '{}'::jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.app_data_branches (
  branch_key text not null,
  data jsonb default '{}'::jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.batches (
  id bigint generated always as identity not null,
  local_id text not null,
  filial text not null,
  pid bigint not null,
  bno text,
  origin text,
  cur text default 'USD'::text,
  qty numeric default 0 not null,
  sold numeric default 0 not null,
  cost_usd numeric default 0 not null,
  bank_fee_usd numeric default 0 not null,
  supp_id bigint,
  consignment boolean default false not null,
  rate_usd_uzs numeric,
  rate_usd_cny numeric,
  batch_date date,
  status text default 'active'::text,
  performed_by text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.bot_sessions (
  chat_id text not null,
  dealer_id bigint,
  state text default 'idle'::text not null,
  data jsonb default '{}'::jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.cashbox_balances (
  filial text not null,
  box_local_id integer not null,
  balance numeric default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.cashbox_transactions (
  id bigint generated always as identity not null,
  filial text not null,
  box_local_id integer not null,
  box_name text,
  type text not null,
  amount numeric not null,
  desc_text text,
  staff_id bigint,
  staff_name text,
  idem_key text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.catalog_products (
  id bigint not null,
  sku text,
  name text,
  qty numeric default 0 not null,
  updated_at timestamp with time zone default now() not null,
  point_pct numeric default 0 not null,
  optim_price numeric default 0 not null,
  filial text default 'baza'::text not null,
  image text
);

create table if not exists public.customer_balances (
  filial text not null,
  customer_local_id bigint not null,
  debt numeric default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.customer_debt_payments (
  id bigint generated always as identity not null,
  filial text not null,
  customer_local_id integer not null,
  customer_name text,
  amount_uzs numeric not null,
  box_local_id integer,
  staff_id bigint,
  staff_name text,
  idem_key text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dealer_audit_log (
  id uuid default gen_random_uuid() not null,
  dealer_id bigint not null,
  action text not null,
  actor_kind text not null,
  actor_name text,
  actor_staff_id bigint,
  filial text not null,
  old_value jsonb,
  new_value jsonb,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dealer_orders (
  id bigint generated always as identity not null,
  dealer_id bigint not null,
  items jsonb not null,
  status text default 'pending'::text not null,
  note text,
  created_at timestamp with time zone default now() not null,
  resolved_at timestamp with time zone
);

create table if not exists public.dealer_payments (
  id bigint generated always as identity not null,
  dealer_id bigint not null,
  amount_usd numeric not null,
  note text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dealer_sales (
  id bigint generated always as identity not null,
  dealer_id bigint not null,
  pid bigint not null,
  sku text,
  name text,
  qty numeric not null,
  sell_usd numeric not null,
  total_usd numeric not null,
  sale_date date default CURRENT_DATE not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.dealer_stock (
  id bigint generated always as identity not null,
  dealer_id bigint not null,
  pid bigint not null,
  sku text,
  name text,
  qty numeric default 0 not null,
  avg_cost_usd numeric default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.dealer_stock_moves (
  id bigint generated always as identity not null,
  dealer_id bigint not null,
  type text not null,
  pid bigint not null,
  sku text,
  name text,
  qty numeric not null,
  cost_usd numeric default 0 not null,
  created_at timestamp with time zone default now() not null,
  reason text,
  condition text
);

create table if not exists public.dealers (
  id bigint generated always as identity not null,
  auth_user_id uuid,
  login text not null,
  name text not null,
  phone text,
  region text,
  debt_usd numeric default 0 not null,
  total_shipped_usd numeric default 0 not null,
  total_sold_usd numeric default 0 not null,
  total_paid_usd numeric default 0 not null,
  color text,
  av text,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  commission_pct numeric default 0 not null,
  telegram_chat_id text,
  points numeric default 0 not null,
  filial text default 'baza'::text not null,
  credit_limit_usd numeric default 0 not null,
  payment_due_days integer default 30 not null
);

create table if not exists public.home_withdrawals (
  id bigint generated always as identity not null,
  filial text not null,
  entries jsonb not null,
  note text,
  staff_id bigint,
  staff_name text,
  idem_key text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.idempotency_keys (
  id bigint generated always as identity not null,
  idem_key text not null,
  endpoint text not null,
  response jsonb,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.login_security (
  login text not null,
  failed_attempts integer default 0 not null,
  lock_stage integer default 0 not null,
  locked_until timestamp with time zone,
  last_failed_at timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.partner_ledger (
  id bigint generated always as identity not null,
  partner_id bigint not null,
  entry_type text not null,
  debit numeric(14,2) default 0 not null,
  credit numeric(14,2) default 0 not null,
  currency text default 'USD'::text not null,
  ref_type text,
  ref_id text,
  period_id bigint,
  note text,
  reversed_by bigint,
  created_by text,
  pct_snapshot numeric(6,2),
  created_at timestamp with time zone default now() not null
);

create table if not exists public.partner_ledger_legacy_history (
  id bigint generated always as identity not null,
  partner_id bigint not null,
  event_date date not null,
  description text not null,
  delta numeric(14,2) not null,
  reconstructed_balance numeric(14,2),
  source text not null,
  imported_at timestamp with time zone default now() not null
);

create table if not exists public.partner_payments (
  id bigint generated always as identity not null,
  partner_id bigint not null,
  amount numeric(14,2) not null,
  method text,
  cashbox_id integer,
  note text,
  idempotency_key text,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.partner_periods (
  id bigint generated always as identity not null,
  legacy_id text,
  period_start date not null,
  period_end date not null,
  total_profit numeric(14,2) not null,
  total_capital_base numeric(14,2) not null,
  tasischi_expense numeric(14,2) default 0 not null,
  status text default 'active'::text not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.partners (
  id bigint generated always as identity not null,
  legacy_id bigint,
  name text not null,
  partner_type text default 'BUSINESS_OWNER'::text not null,
  investment_pct numeric(5,2),
  is_founder boolean default false not null,
  keep_pct numeric(5,2) default 0 not null,
  color text,
  avatar text,
  status text default 'active'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.permissions (
  id uuid default gen_random_uuid() not null,
  key text not null,
  module text not null,
  label text not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.role_permissions (
  role_id uuid not null,
  permission_id uuid not null
);

create table if not exists public.roles (
  id uuid default gen_random_uuid() not null,
  key text not null,
  name text not null,
  description text,
  is_system boolean default false not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.sales (
  id bigint generated always as identity not null,
  filial text not null,
  inv text not null,
  cust_id bigint,
  subtotal_usd numeric not null,
  disc_pct numeric default 0 not null,
  total_usd numeric not null,
  cost_usd numeric not null,
  profit_usd numeric not null,
  paid_usd numeric not null,
  debt_usd numeric default 0 not null,
  items jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.staff (
  id bigint generated always as identity not null,
  auth_user_id uuid,
  login text not null,
  name text not null,
  role text default 'sotuvchi'::text not null,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  filial text default 'baza'::text not null
);

create table if not exists public.staff_audit_log (
  id bigint generated always as identity not null,
  staff_id bigint,
  staff_name text,
  filial text,
  action text not null,
  details jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.staff_roles (
  staff_id bigint not null,
  role_id uuid not null
);

create table if not exists public.supplier_balances (
  filial text not null,
  supplier_local_id bigint not null,
  debt numeric default 0 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.supplier_payments (
  id bigint generated always as identity not null,
  filial text not null,
  supplier_local_id integer not null,
  supplier_name text,
  amount_usd numeric not null,
  box_local_id integer,
  staff_id bigint,
  staff_name text,
  idem_key text,
  created_at timestamp with time zone default now() not null
);

-- ────────────────────────────────────────────────────────────────────
-- 2. KALITLAR, CHEKLOVLAR, INDEKSLAR, RLS
-- ────────────────────────────────────────────────────────────────────
do $$ begin if not exists (select 1 from pg_constraint where conname='app_data_branches_pkey' and conrelid='public.app_data_branches'::regclass) then alter table public.app_data_branches add constraint app_data_branches_pkey PRIMARY KEY (branch_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='app_data_pkey' and conrelid='public.app_data'::regclass) then alter table public.app_data add constraint app_data_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='batches_pkey' and conrelid='public.batches'::regclass) then alter table public.batches add constraint batches_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='bot_sessions_pkey' and conrelid='public.bot_sessions'::regclass) then alter table public.bot_sessions add constraint bot_sessions_pkey PRIMARY KEY (chat_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='cashbox_balances_pkey' and conrelid='public.cashbox_balances'::regclass) then alter table public.cashbox_balances add constraint cashbox_balances_pkey PRIMARY KEY (filial, box_local_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='cashbox_transactions_pkey' and conrelid='public.cashbox_transactions'::regclass) then alter table public.cashbox_transactions add constraint cashbox_transactions_pkey PRIMARY KEY (id); end if; end $$;
alter table public.catalog_products add column if not exists image text;
do $$ begin if not exists (select 1 from pg_constraint where conname='catalog_products_image_https' and conrelid='public.catalog_products'::regclass) then alter table public.catalog_products add constraint catalog_products_image_https CHECK (image is null or (image ~* '^https://' and length(image) <= 1000)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='catalog_products_pkey' and conrelid='public.catalog_products'::regclass) then alter table public.catalog_products add constraint catalog_products_pkey PRIMARY KEY (id, filial); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='customer_balances_pkey' and conrelid='public.customer_balances'::regclass) then alter table public.customer_balances add constraint customer_balances_pkey PRIMARY KEY (filial, customer_local_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='customer_debt_payments_pkey' and conrelid='public.customer_debt_payments'::regclass) then alter table public.customer_debt_payments add constraint customer_debt_payments_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_audit_log_pkey' and conrelid='public.dealer_audit_log'::regclass) then alter table public.dealer_audit_log add constraint dealer_audit_log_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_orders_pkey' and conrelid='public.dealer_orders'::regclass) then alter table public.dealer_orders add constraint dealer_orders_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_payments_pkey' and conrelid='public.dealer_payments'::regclass) then alter table public.dealer_payments add constraint dealer_payments_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_sales_pkey' and conrelid='public.dealer_sales'::regclass) then alter table public.dealer_sales add constraint dealer_sales_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_stock_moves_pkey' and conrelid='public.dealer_stock_moves'::regclass) then alter table public.dealer_stock_moves add constraint dealer_stock_moves_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_stock_pkey' and conrelid='public.dealer_stock'::regclass) then alter table public.dealer_stock add constraint dealer_stock_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealers_pkey' and conrelid='public.dealers'::regclass) then alter table public.dealers add constraint dealers_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='home_withdrawals_pkey' and conrelid='public.home_withdrawals'::regclass) then alter table public.home_withdrawals add constraint home_withdrawals_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='idempotency_keys_pkey' and conrelid='public.idempotency_keys'::regclass) then alter table public.idempotency_keys add constraint idempotency_keys_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='login_security_pkey' and conrelid='public.login_security'::regclass) then alter table public.login_security add constraint login_security_pkey PRIMARY KEY (login); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_legacy_history_pkey' and conrelid='public.partner_ledger_legacy_history'::regclass) then alter table public.partner_ledger_legacy_history add constraint partner_ledger_legacy_history_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_pkey' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_payments_pkey' and conrelid='public.partner_payments'::regclass) then alter table public.partner_payments add constraint partner_payments_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_periods_pkey' and conrelid='public.partner_periods'::regclass) then alter table public.partner_periods add constraint partner_periods_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partners_pkey' and conrelid='public.partners'::regclass) then alter table public.partners add constraint partners_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='permissions_pkey' and conrelid='public.permissions'::regclass) then alter table public.permissions add constraint permissions_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='role_permissions_pkey' and conrelid='public.role_permissions'::regclass) then alter table public.role_permissions add constraint role_permissions_pkey PRIMARY KEY (role_id, permission_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='roles_pkey' and conrelid='public.roles'::regclass) then alter table public.roles add constraint roles_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='sales_pkey' and conrelid='public.sales'::regclass) then alter table public.sales add constraint sales_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_audit_log_pkey' and conrelid='public.staff_audit_log'::regclass) then alter table public.staff_audit_log add constraint staff_audit_log_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_roles_pkey' and conrelid='public.staff_roles'::regclass) then alter table public.staff_roles add constraint staff_roles_pkey PRIMARY KEY (staff_id, role_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_pkey' and conrelid='public.staff'::regclass) then alter table public.staff add constraint staff_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='supplier_balances_pkey' and conrelid='public.supplier_balances'::regclass) then alter table public.supplier_balances add constraint supplier_balances_pkey PRIMARY KEY (filial, supplier_local_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='supplier_payments_pkey' and conrelid='public.supplier_payments'::regclass) then alter table public.supplier_payments add constraint supplier_payments_pkey PRIMARY KEY (id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='batches_filial_local_id_key' and conrelid='public.batches'::regclass) then alter table public.batches add constraint batches_filial_local_id_key UNIQUE (filial, local_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='cashbox_transactions_idem_key_key' and conrelid='public.cashbox_transactions'::regclass) then alter table public.cashbox_transactions add constraint cashbox_transactions_idem_key_key UNIQUE (idem_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='customer_debt_payments_idem_key_key' and conrelid='public.customer_debt_payments'::regclass) then alter table public.customer_debt_payments add constraint customer_debt_payments_idem_key_key UNIQUE (idem_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_stock_dealer_id_pid_key' and conrelid='public.dealer_stock'::regclass) then alter table public.dealer_stock add constraint dealer_stock_dealer_id_pid_key UNIQUE (dealer_id, pid); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealers_auth_user_id_key' and conrelid='public.dealers'::regclass) then alter table public.dealers add constraint dealers_auth_user_id_key UNIQUE (auth_user_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealers_login_key' and conrelid='public.dealers'::regclass) then alter table public.dealers add constraint dealers_login_key UNIQUE (login); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='home_withdrawals_idem_key_key' and conrelid='public.home_withdrawals'::regclass) then alter table public.home_withdrawals add constraint home_withdrawals_idem_key_key UNIQUE (idem_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='idempotency_keys_idem_key_key' and conrelid='public.idempotency_keys'::regclass) then alter table public.idempotency_keys add constraint idempotency_keys_idem_key_key UNIQUE (idem_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_payments_idempotency_key_key' and conrelid='public.partner_payments'::regclass) then alter table public.partner_payments add constraint partner_payments_idempotency_key_key UNIQUE (idempotency_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_periods_legacy_id_key' and conrelid='public.partner_periods'::regclass) then alter table public.partner_periods add constraint partner_periods_legacy_id_key UNIQUE (legacy_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partners_legacy_id_key' and conrelid='public.partners'::regclass) then alter table public.partners add constraint partners_legacy_id_key UNIQUE (legacy_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='permissions_key_key' and conrelid='public.permissions'::regclass) then alter table public.permissions add constraint permissions_key_key UNIQUE (key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='roles_key_key' and conrelid='public.roles'::regclass) then alter table public.roles add constraint roles_key_key UNIQUE (key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='sales_filial_inv_key' and conrelid='public.sales'::regclass) then alter table public.sales add constraint sales_filial_inv_key UNIQUE (filial, inv); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_auth_user_id_key' and conrelid='public.staff'::regclass) then alter table public.staff add constraint staff_auth_user_id_key UNIQUE (auth_user_id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_login_key' and conrelid='public.staff'::regclass) then alter table public.staff add constraint staff_login_key UNIQUE (login); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='supplier_payments_idem_key_key' and conrelid='public.supplier_payments'::regclass) then alter table public.supplier_payments add constraint supplier_payments_idem_key_key UNIQUE (idem_key); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='cashbox_transactions_amount_check' and conrelid='public.cashbox_transactions'::regclass) then alter table public.cashbox_transactions add constraint cashbox_transactions_amount_check CHECK ((amount > (0)::numeric)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='cashbox_transactions_type_check' and conrelid='public.cashbox_transactions'::regclass) then alter table public.cashbox_transactions add constraint cashbox_transactions_type_check CHECK ((type = ANY (ARRAY['in'::text, 'out'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='customer_debt_payments_amount_uzs_check' and conrelid='public.customer_debt_payments'::regclass) then alter table public.customer_debt_payments add constraint customer_debt_payments_amount_uzs_check CHECK ((amount_uzs > (0)::numeric)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_orders_status_check' and conrelid='public.dealer_orders'::regclass) then alter table public.dealer_orders add constraint dealer_orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_stock_moves_type_check' and conrelid='public.dealer_stock_moves'::regclass) then alter table public.dealer_stock_moves add constraint dealer_stock_moves_type_check CHECK ((type = ANY (ARRAY['send'::text, 'return'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='login_security_failed_attempts_check' and conrelid='public.login_security'::regclass) then alter table public.login_security add constraint login_security_failed_attempts_check CHECK ((failed_attempts >= 0)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='login_security_lock_stage_check' and conrelid='public.login_security'::regclass) then alter table public.login_security add constraint login_security_lock_stage_check CHECK ((lock_stage = ANY (ARRAY[0, 1, 2]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_legacy_history_source_check' and conrelid='public.partner_ledger_legacy_history'::regclass) then alter table public.partner_ledger_legacy_history add constraint partner_ledger_legacy_history_source_check CHECK ((source = ANY (ARRAY['legacy_expense'::text, 'legacy_period'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='chk_ledger_one_side' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint chk_ledger_one_side CHECK ((((debit > (0)::numeric) AND (credit = (0)::numeric)) OR ((credit > (0)::numeric) AND (debit = (0)::numeric)))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_credit_check' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_credit_check CHECK ((credit >= (0)::numeric)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_currency_check' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_currency_check CHECK ((currency = 'USD'::text)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_debit_check' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_debit_check CHECK ((debit >= (0)::numeric)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_entry_type_check' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_entry_type_check CHECK ((entry_type = ANY (ARRAY['capital_in'::text, 'profit_share'::text, 'withdrawal'::text, 'expense_charge'::text, 'expense_reversal'::text, 'adjustment'::text, 'reversal'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_payments_amount_check' and conrelid='public.partner_payments'::regclass) then alter table public.partner_payments add constraint partner_payments_amount_check CHECK ((amount > (0)::numeric)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='chk_period_dates' and conrelid='public.partner_periods'::regclass) then alter table public.partner_periods add constraint chk_period_dates CHECK ((period_end >= period_start)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_periods_status_check' and conrelid='public.partner_periods'::regclass) then alter table public.partner_periods add constraint partner_periods_status_check CHECK ((status = ANY (ARRAY['active'::text, 'undone'::text, 'legacy_snapshot'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partners_check' and conrelid='public.partners'::regclass) then alter table public.partners add constraint partners_check CHECK (((investment_pct IS NULL) OR (((partner_type = 'INVESTOR'::text) AND (investment_pct >= (10)::numeric) AND (investment_pct <= (100)::numeric)) OR ((partner_type <> 'INVESTOR'::text) AND (investment_pct > (0)::numeric) AND (investment_pct <= (100)::numeric))))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partners_keep_pct_check' and conrelid='public.partners'::regclass) then alter table public.partners add constraint partners_keep_pct_check CHECK (((keep_pct >= (0)::numeric) AND (keep_pct <= (100)::numeric))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partners_partner_type_check' and conrelid='public.partners'::regclass) then alter table public.partners add constraint partners_partner_type_check CHECK ((partner_type <> ''::text)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partners_status_check' and conrelid='public.partners'::regclass) then alter table public.partners add constraint partners_status_check CHECK ((status = ANY (ARRAY['active'::text, 'archived'::text]))); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='supplier_payments_amount_usd_check' and conrelid='public.supplier_payments'::regclass) then alter table public.supplier_payments add constraint supplier_payments_amount_usd_check CHECK ((amount_usd > (0)::numeric)); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='bot_sessions_dealer_id_fkey' and conrelid='public.bot_sessions'::regclass) then alter table public.bot_sessions add constraint bot_sessions_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE SET NULL; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_audit_log_dealer_id_fkey' and conrelid='public.dealer_audit_log'::regclass) then alter table public.dealer_audit_log add constraint dealer_audit_log_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_orders_dealer_id_fkey' and conrelid='public.dealer_orders'::regclass) then alter table public.dealer_orders add constraint dealer_orders_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_payments_dealer_id_fkey' and conrelid='public.dealer_payments'::regclass) then alter table public.dealer_payments add constraint dealer_payments_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_sales_dealer_id_fkey' and conrelid='public.dealer_sales'::regclass) then alter table public.dealer_sales add constraint dealer_sales_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_stock_moves_dealer_id_fkey' and conrelid='public.dealer_stock_moves'::regclass) then alter table public.dealer_stock_moves add constraint dealer_stock_moves_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealer_stock_dealer_id_fkey' and conrelid='public.dealer_stock'::regclass) then alter table public.dealer_stock add constraint dealer_stock_dealer_id_fkey FOREIGN KEY (dealer_id) REFERENCES dealers(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='dealers_auth_user_id_fkey' and conrelid='public.dealers'::regclass) then alter table public.dealers add constraint dealers_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_legacy_history_partner_id_fkey' and conrelid='public.partner_ledger_legacy_history'::regclass) then alter table public.partner_ledger_legacy_history add constraint partner_ledger_legacy_history_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partners(id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_partner_id_fkey' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partners(id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_period_id_fkey' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_period_id_fkey FOREIGN KEY (period_id) REFERENCES partner_periods(id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_ledger_reversed_by_fkey' and conrelid='public.partner_ledger'::regclass) then alter table public.partner_ledger add constraint partner_ledger_reversed_by_fkey FOREIGN KEY (reversed_by) REFERENCES partner_ledger(id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='partner_payments_partner_id_fkey' and conrelid='public.partner_payments'::regclass) then alter table public.partner_payments add constraint partner_payments_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partners(id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='role_permissions_permission_id_fkey' and conrelid='public.role_permissions'::regclass) then alter table public.role_permissions add constraint role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='role_permissions_role_id_fkey' and conrelid='public.role_permissions'::regclass) then alter table public.role_permissions add constraint role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_audit_log_staff_id_fkey' and conrelid='public.staff_audit_log'::regclass) then alter table public.staff_audit_log add constraint staff_audit_log_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id); end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_roles_role_id_fkey' and conrelid='public.staff_roles'::regclass) then alter table public.staff_roles add constraint staff_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_roles_staff_id_fkey' and conrelid='public.staff_roles'::regclass) then alter table public.staff_roles add constraint staff_roles_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE; end if; end $$;
do $$ begin if not exists (select 1 from pg_constraint where conname='staff_auth_user_id_fkey' and conrelid='public.staff'::regclass) then alter table public.staff add constraint staff_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL; end if; end $$;
create index if not exists dealer_audit_log_dealer_idx ON public.dealer_audit_log USING btree (dealer_id, created_at DESC);
create index if not exists dealer_audit_log_filial_idx ON public.dealer_audit_log USING btree (filial, created_at DESC);
create index if not exists idx_batches_filial ON public.batches USING btree (filial);
create index if not exists idx_batches_pid ON public.batches USING btree (filial, pid);
create index if not exists idx_batches_status ON public.batches USING btree (filial, status);
create index if not exists idx_cashbox_txn_filial ON public.cashbox_transactions USING btree (filial, created_at);
create index if not exists idx_catalog_filial ON public.catalog_products USING btree (filial);
create index if not exists idx_cust_pay_filial ON public.customer_debt_payments USING btree (filial, created_at);
create index if not exists idx_dealer_moves_dealer ON public.dealer_stock_moves USING btree (dealer_id);
create index if not exists idx_dealer_orders_dealer ON public.dealer_orders USING btree (dealer_id, status);
create index if not exists idx_dealer_payments_dealer ON public.dealer_payments USING btree (dealer_id);
create index if not exists idx_dealer_sales_dealer ON public.dealer_sales USING btree (dealer_id, sale_date);
create index if not exists idx_dealer_stock_dealer ON public.dealer_stock USING btree (dealer_id);
create index if not exists idx_dealers_filial ON public.dealers USING btree (filial);
create index if not exists idx_home_withdraw_filial ON public.home_withdrawals USING btree (filial, created_at);
create index if not exists idx_idem_key ON public.idempotency_keys USING btree (idem_key);
create index if not exists idx_legacy_history_partner ON public.partner_ledger_legacy_history USING btree (partner_id);
create index if not exists idx_partner_ledger_partner ON public.partner_ledger USING btree (partner_id);
create index if not exists idx_partner_ledger_period ON public.partner_ledger USING btree (period_id);
create index if not exists idx_partner_ledger_reftype ON public.partner_ledger USING btree (ref_type, ref_id);
create index if not exists idx_partner_payments_partner ON public.partner_payments USING btree (partner_id);
create index if not exists idx_sales_filial ON public.sales USING btree (filial, created_at);
create index if not exists idx_staff_audit_log_created ON public.staff_audit_log USING btree (created_at DESC);
create index if not exists idx_staff_audit_log_staff ON public.staff_audit_log USING btree (staff_id);
create index if not exists idx_staff_filial ON public.staff USING btree (filial);
create index if not exists idx_supp_pay_filial ON public.supplier_payments USING btree (filial, created_at);
alter table public.app_data enable row level security;
alter table public.app_data_branches enable row level security;
alter table public.batches enable row level security;
alter table public.bot_sessions enable row level security;
alter table public.cashbox_balances enable row level security;
alter table public.cashbox_transactions enable row level security;
alter table public.catalog_products enable row level security;
alter table public.customer_balances enable row level security;
alter table public.customer_debt_payments enable row level security;
alter table public.dealer_audit_log enable row level security;
alter table public.dealer_orders enable row level security;
alter table public.dealer_payments enable row level security;
alter table public.dealer_sales enable row level security;
alter table public.dealer_stock enable row level security;
alter table public.dealer_stock_moves enable row level security;
alter table public.dealers enable row level security;
alter table public.home_withdrawals enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.login_security enable row level security;
alter table public.partner_ledger enable row level security;
alter table public.partner_ledger_legacy_history enable row level security;
alter table public.partner_payments enable row level security;
alter table public.partner_periods enable row level security;
alter table public.partners enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.roles enable row level security;
alter table public.sales enable row level security;
alter table public.staff enable row level security;
alter table public.staff_audit_log enable row level security;
alter table public.staff_roles enable row level security;
alter table public.supplier_balances enable row level security;
alter table public.supplier_payments enable row level security;

-- ────────────────────────────────────────────────────────────────────
-- 3a. FUNKSIYALAR: login xavfsizligi, diller savdosi, RLS-avto
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.login_check_lock(p_login text)
 RETURNS TABLE(is_locked boolean, locked_until timestamp with time zone, lock_stage integer, seconds_remaining integer)
 LANGUAGE plpgsql
AS $function$
DECLARE v_row login_security%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM login_security WHERE login = p_login;
  IF NOT FOUND OR v_row.locked_until IS NULL OR v_row.locked_until <= now() THEN
    RETURN QUERY SELECT false, NULL::timestamptz, COALESCE(v_row.lock_stage,0), 0;
  ELSE
    RETURN QUERY SELECT true, v_row.locked_until, v_row.lock_stage, CEIL(EXTRACT(EPOCH FROM (v_row.locked_until - now())))::int;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.login_record_failure(p_login text)
 RETURNS TABLE(failed_attempts integer, lock_stage integer, locked_until timestamp with time zone, just_locked boolean)
 LANGUAGE plpgsql
AS $function$
DECLARE v_row login_security%ROWTYPE; v_just_locked boolean := false;
BEGIN
  INSERT INTO login_security (login, failed_attempts, last_failed_at, updated_at)
  VALUES (p_login, 0, now(), now())
  ON CONFLICT (login) DO NOTHING;

  SELECT * INTO v_row FROM login_security WHERE login=p_login FOR UPDATE;

  UPDATE login_security ls SET
    failed_attempts = ls.failed_attempts + 1,
    last_failed_at = now(),
    updated_at = now()
  WHERE ls.login = p_login
  RETURNING * INTO v_row;

  IF v_row.failed_attempts >= 3 AND v_row.lock_stage = 0 THEN
    UPDATE login_security ls SET lock_stage=1, locked_until= now() + interval '10 minutes', failed_attempts=0, updated_at=now()
    WHERE ls.login=p_login RETURNING * INTO v_row;
    v_just_locked := true;
  ELSIF v_row.failed_attempts >= 3 AND v_row.lock_stage = 1 THEN
    UPDATE login_security ls SET lock_stage=2, locked_until= now() + interval '30 hours', failed_attempts=0, updated_at=now()
    WHERE ls.login=p_login RETURNING * INTO v_row;
    v_just_locked := true;
  END IF;

  RETURN QUERY SELECT v_row.failed_attempts, v_row.lock_stage, v_row.locked_until, v_just_locked;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.login_record_success(p_login text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO login_security (login, failed_attempts, lock_stage, locked_until, last_failed_at, updated_at)
  VALUES (p_login, 0, 0, NULL, NULL, now())
  ON CONFLICT (login) DO UPDATE SET failed_attempts=0, lock_stage=0, locked_until=NULL, updated_at=now();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dealer_id bigint;
  v_stock numeric;
begin
  select id into v_dealer_id from dealers where auth_user_id = auth.uid();
  if v_dealer_id is null then
    raise exception 'Diller topilmadi, avval tizimga kiring';
  end if;
  if p_qty <= 0 then
    raise exception 'Miqdor 0 dan katta bolishi kerak';
  end if;

  select qty into v_stock from dealer_stock where dealer_id = v_dealer_id and pid = p_pid;
  if v_stock is null or v_stock < p_qty then
    raise exception 'Omborda yetarli mahsulot yoq (bor: %, soralgan: %)', coalesce(v_stock,0), p_qty;
  end if;

  update dealer_stock set qty = qty - p_qty, updated_at = now()
    where dealer_id = v_dealer_id and pid = p_pid;

  insert into dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
    values (v_dealer_id, p_pid, p_sku, p_name, p_qty, p_sell_usd, p_qty*p_sell_usd, current_date);

  update dealers set
    total_sold_usd = total_sold_usd + (p_qty*p_sell_usd),
    debt_usd        = debt_usd + (p_qty*p_sell_usd)
  where id = v_dealer_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dealer_id bigint;
  v_stock numeric;
begin
  select id into v_dealer_id from dealers where auth_user_id = auth.uid();
  if v_dealer_id is null then
    raise exception 'Diller topilmadi, avval tizimga kiring';
  end if;
  if p_qty <= 0 then
    raise exception 'Miqdor 0 dan katta bolishi kerak';
  end if;

  select qty into v_stock from dealer_stock where dealer_id = v_dealer_id and pid = p_pid;
  if v_stock is null or v_stock < p_qty then
    raise exception 'Omborda yetarli mahsulot yoq (bor: %, soralgan: %)', coalesce(v_stock,0), p_qty;
  end if;

  update dealer_stock set qty = qty - p_qty, updated_at = now()
    where dealer_id = v_dealer_id and pid = p_pid;

  insert into dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
    values (v_dealer_id, p_pid, p_sku, p_name, p_qty, p_sell_usd, p_qty*p_sell_usd, current_date);

  update dealers set
    total_sold_usd = total_sold_usd + (p_qty*p_sell_usd),
    debt_usd        = debt_usd + (p_qty*p_sell_usd),
    points          = points + coalesce(p_points,0)
  where id = v_dealer_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric DEFAULT 0, p_optim_price numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dealer_id bigint;
  v_stock numeric;
  v_optim numeric;
begin
  select id into v_dealer_id from dealers where auth_user_id = auth.uid();
  if v_dealer_id is null then
    raise exception 'Diller topilmadi, avval tizimga kiring';
  end if;
  if p_qty <= 0 then
    raise exception 'Miqdor 0 dan katta bolishi kerak';
  end if;

  select qty into v_stock from dealer_stock where dealer_id = v_dealer_id and pid = p_pid;
  if v_stock is null or v_stock < p_qty then
    raise exception 'Omborda yetarli mahsulot yoq (bor: %, soralgan: %)', coalesce(v_stock,0), p_qty;
  end if;

  v_optim := coalesce(p_optim_price, p_sell_usd);

  update dealer_stock set qty = qty - p_qty, updated_at = now()
    where dealer_id = v_dealer_id and pid = p_pid;

  insert into dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
    values (v_dealer_id, p_pid, p_sku, p_name, p_qty, p_sell_usd, p_qty*p_sell_usd, current_date);

  update dealers set
    total_sold_usd = total_sold_usd + (p_qty*p_sell_usd),
    debt_usd        = debt_usd + (p_qty*v_optim),
    points          = points + coalesce(p_points,0)
  where id = v_dealer_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

-- ────────────────────────────────────────────────────────────────────
-- 3b. FUNKSIYA: savdo (atomik, aralash to'lov) — sale_checkout_atomic_v2
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sale_checkout_atomic_v2(p_filial text, p_items jsonb, p_disc_pct numeric, p_paid_usd numeric, p_cust_id bigint, p_box_payments jsonb, p_inv text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_item jsonb;
  v_bp jsonb;
  v_pid bigint;
  v_qty numeric;
  v_remaining numeric;
  v_batch record;
  v_take numeric;
  v_subtotal numeric := 0;
  v_total numeric;
  v_cost numeric := 0;
  v_profit numeric;
  v_debt numeric;
  v_change numeric;
  v_sale_id bigint;
begin
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_subtotal := v_subtotal + (v_item->>'qty')::numeric * (v_item->>'sell_usd')::numeric;
  end loop;
  v_total := v_subtotal * (1 - coalesce(p_disc_pct,0)/100);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'pid')::bigint;
    v_qty := (v_item->>'qty')::numeric;

    if coalesce((v_item->>'direct_supply')::boolean, false) then
      v_cost := v_cost + v_qty * (v_item->>'cost_usd')::numeric;
      if v_item->>'supp_id' is not null then
        insert into public.supplier_balances (filial, supplier_local_id, debt)
          values (p_filial, (v_item->>'supp_id')::bigint, v_qty * (v_item->>'cost_usd')::numeric)
          on conflict (filial, supplier_local_id) do update
            set debt = public.supplier_balances.debt + excluded.debt, updated_at = now();
      end if;
    else
      v_remaining := v_qty;
      for v_batch in
        select id, qty, sold, cost_usd from public.batches
        where filial = p_filial and pid = v_pid and status = 'active' and qty > sold
        order by batch_date asc nulls last, id asc
        for update
      loop
        exit when v_remaining <= 0;
        v_take := least(v_batch.qty - v_batch.sold, v_remaining);
        update public.batches set sold = sold + v_take,
               status = case when qty <= sold + v_take then 'empty' else status end,
               updated_at = now()
          where id = v_batch.id;
        v_cost := v_cost + v_take * v_batch.cost_usd;
        v_remaining := v_remaining - v_take;
      end loop;
      if v_remaining > 0 then
        raise exception 'Omborda yetarli qoldiq yo''q: pid=%, yetishmayotgan miqdor=%', v_pid, v_remaining;
      end if;
    end if;
  end loop;

  v_profit := v_total - v_cost;
  v_debt := greatest(0, v_total - p_paid_usd);
  v_change := greatest(0, p_paid_usd - v_total);

  insert into public.sales (filial, inv, cust_id, subtotal_usd, disc_pct, total_usd, cost_usd, profit_usd, paid_usd, debt_usd, items)
    values (p_filial, p_inv, p_cust_id, v_subtotal, coalesce(p_disc_pct,0), v_total, v_cost, v_profit, least(p_paid_usd, v_total), v_debt, p_items)
    returning id into v_sale_id;

  if p_cust_id is not null and v_debt > 0 then
    insert into public.customer_balances (filial, customer_local_id, debt)
      values (p_filial, p_cust_id, v_debt)
      on conflict (filial, customer_local_id) do update
        set debt = public.customer_balances.debt + excluded.debt, updated_at = now();
  end if;

  -- MIXED-PAYMENT: bir nechta kassaga bo'lingan to'lov — HAR BIRI ham
  -- shu bitta tranzaksiya ichida, atomik ravishda yangilanadi.
  if p_box_payments is not null then
    for v_bp in select * from jsonb_array_elements(p_box_payments) loop
      insert into public.cashbox_balances (filial, box_local_id, balance)
        values (p_filial, (v_bp->>'box_id')::bigint, (v_bp->>'amount_native')::numeric)
        on conflict (filial, box_local_id) do update
          set balance = public.cashbox_balances.balance + excluded.balance, updated_at = now();
    end loop;
  end if;

  return jsonb_build_object(
    'ok', true, 'saleId', v_sale_id, 'inv', p_inv,
    'subtotalUsd', v_subtotal, 'totalUsd', v_total, 'costUsd', v_cost,
    'profitUsd', v_profit, 'debtUsd', v_debt, 'changeUsd', v_change
  );
end;
$function$
;

-- ────────────────────────────────────────────────────────────────────
-- 3c. ESKI FUNKSIYALAR (production'da bor, kod ishlatmaydi — moslik uchun)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dealer_sale_atomic(p_dealer_id bigint, p_items jsonb, p_sale_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_item jsonb;
  v_available numeric;
  v_total numeric;
  v_pid bigint;
  v_qty numeric;
begin
  -- 1-QADAM: BARCHA itemlar uchun qoldiq yetarliligini OLDINDAN tekshiramiz.
  -- Agar bittasi ham yetarli bo'lmasa — HECH NARSA yozilmaydi (all-or-nothing).
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'pid')::bigint;
    v_qty := (v_item->>'qty')::numeric;
    select qty into v_available from public.dealer_stock where dealer_id = p_dealer_id and pid = v_pid;
    if v_available is null or v_available < v_qty then
      raise exception 'Yetarli qoldiq yo''q: pid=%, mavjud=%, so''ralgan=%', v_pid, coalesce(v_available,0), v_qty;
    end if;
  end loop;

  -- 2-QADAM: endi haqiqatan yozamiz — savdo + qoldiq kamayishi BIRGA,
  -- bitta tranzaksiya ichida (xato bo'lsa — ikkalasi ham bekor bo'ladi).
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'pid')::bigint;
    v_qty := (v_item->>'qty')::numeric;
    v_total := v_qty * (v_item->>'sell_usd')::numeric;
    insert into public.dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
      values (p_dealer_id, v_pid, v_item->>'sku', v_item->>'name', v_qty, (v_item->>'sell_usd')::numeric, v_total, p_sale_date);
    update public.dealer_stock set qty = qty - v_qty, updated_at = now()
      where dealer_id = p_dealer_id and pid = v_pid;
  end loop;

  return jsonb_build_object('ok', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sale_checkout_atomic(p_filial text, p_items jsonb, p_disc_pct numeric, p_paid_usd numeric, p_cust_id bigint, p_box_id bigint, p_box_amount_native numeric, p_inv text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_item jsonb;
  v_pid bigint;
  v_qty numeric;
  v_remaining numeric;
  v_batch record;
  v_take numeric;
  v_subtotal numeric := 0;
  v_total numeric;
  v_cost numeric := 0;
  v_profit numeric;
  v_debt numeric;
  v_change numeric;
  v_sale_id bigint;
begin
  -- Subtotal/jami — saleEngine.js bilan AYNAN bir xil formula
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_subtotal := v_subtotal + (v_item->>'qty')::numeric * (v_item->>'sell_usd')::numeric;
  end loop;
  v_total := v_subtotal * (1 - coalesce(p_disc_pct,0)/100);

  -- Har bir item: manbasiga qarab FIFO-kamaytirish YOKI ta'minotchi qarzi
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'pid')::bigint;
    v_qty := (v_item->>'qty')::numeric;

    if coalesce((v_item->>'direct_supply')::boolean, false) then
      v_cost := v_cost + v_qty * (v_item->>'cost_usd')::numeric;
      if v_item->>'supp_id' is not null then
        insert into public.supplier_balances (filial, supplier_local_id, debt)
          values (p_filial, (v_item->>'supp_id')::bigint, v_qty * (v_item->>'cost_usd')::numeric)
          on conflict (filial, supplier_local_id) do update
            set debt = public.supplier_balances.debt + excluded.debt, updated_at = now();
      end if;
    else
      v_remaining := v_qty;
      for v_batch in
        select id, qty, sold, cost_usd from public.batches
        where filial = p_filial and pid = v_pid and status = 'active' and qty > sold
        order by batch_date asc nulls last, id asc
        for update
      loop
        exit when v_remaining <= 0;
        v_take := least(v_batch.qty - v_batch.sold, v_remaining);
        update public.batches set sold = sold + v_take,
               status = case when qty <= sold + v_take then 'empty' else status end,
               updated_at = now()
          where id = v_batch.id;
        v_cost := v_cost + v_take * v_batch.cost_usd;
        v_remaining := v_remaining - v_take;
      end loop;
      if v_remaining > 0 then
        raise exception 'Omborda yetarli qoldiq yo''q: pid=%, yetishmayotgan miqdor=%', v_pid, v_remaining;
      end if;
    end if;
  end loop;

  v_profit := v_total - v_cost;
  v_debt := greatest(0, v_total - p_paid_usd);
  v_change := greatest(0, p_paid_usd - v_total);

  insert into public.sales (filial, inv, cust_id, subtotal_usd, disc_pct, total_usd, cost_usd, profit_usd, paid_usd, debt_usd, items)
    values (p_filial, p_inv, p_cust_id, v_subtotal, coalesce(p_disc_pct,0), v_total, v_cost, v_profit, least(p_paid_usd, v_total), v_debt, p_items)
    returning id into v_sale_id;

  if p_cust_id is not null and v_debt > 0 then
    insert into public.customer_balances (filial, customer_local_id, debt)
      values (p_filial, p_cust_id, v_debt)
      on conflict (filial, customer_local_id) do update
        set debt = public.customer_balances.debt + excluded.debt, updated_at = now();
  end if;

  if p_box_id is not null and p_box_amount_native is not null then
    insert into public.cashbox_balances (filial, box_local_id, balance)
      values (p_filial, p_box_id, p_box_amount_native)
      on conflict (filial, box_local_id) do update
        set balance = public.cashbox_balances.balance + excluded.balance, updated_at = now();
  end if;

  return jsonb_build_object(
    'ok', true, 'saleId', v_sale_id, 'inv', p_inv,
    'subtotalUsd', v_subtotal, 'totalUsd', v_total, 'costUsd', v_cost,
    'profitUsd', v_profit, 'debtUsd', v_debt, 'changeUsd', v_change
  );
end;
$function$
;

-- ────────────────────────────────────────────────────────────────────
-- 3d. HAMKORLAR V2 FUNKSIYALARI (1)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.partner_archive_atomic(p_legacy_id bigint)
 RETURNS TABLE(partner_id bigint, had_ledger_history boolean)
 LANGUAGE plpgsql
AS $function$
DECLARE v_id bigint; v_had_history boolean;
BEGIN
  SELECT id INTO v_id FROM partners WHERE legacy_id=p_legacy_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'HAMKORLAR_V2_ERR: partner legacy_id=% not found', p_legacy_id USING ERRCODE='P0002'; END IF;
  SELECT EXISTS(SELECT 1 FROM partner_ledger pl WHERE pl.partner_id=v_id) INTO v_had_history;
  UPDATE partners SET status='archived', updated_at=now() WHERE id=v_id;
  UPDATE app_data SET data = jsonb_set(
    data, '{partners}',
    (SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(data->'partners') e WHERE (e->>'id')::bigint<>p_legacy_id)
  ), updated_at=now() WHERE id='main';
  RETURN QUERY SELECT v_id, v_had_history;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.partner_ledger_add_atomic(p_legacy_id bigint, p_entry_type text, p_amount numeric, p_ref_type text DEFAULT NULL::text, p_ref_id text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_created_by text DEFAULT NULL::text)
 RETURNS TABLE(partner_id bigint, new_balance numeric)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_partner_id bigint;
  v_debit numeric := 0;
  v_credit numeric := 0;
  v_new_balance numeric;
  v_json_found boolean;
BEGIN
  IF p_amount = 0 THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: amount cannot be 0 (chk_ledger_one_side)' USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_partner_id FROM partners WHERE legacy_id = p_legacy_id;
  IF v_partner_id IS NULL THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: partner legacy_id=% not found in partners table' , p_legacy_id USING ERRCODE = 'P0002';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM app_data, jsonb_array_elements(app_data.data->'partners') elem
    WHERE app_data.id = 'main' AND (elem->>'id')::bigint = p_legacy_id
  ) INTO v_json_found;
  IF NOT v_json_found THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: legacy_id=% not found in app_data JSON — refusing partial write (JSON+ledger must stay atomic)', p_legacy_id USING ERRCODE = 'P0003';
  END IF;

  IF p_amount > 0 THEN v_credit := p_amount; ELSE v_debit := -p_amount; END IF;

  INSERT INTO partner_ledger (partner_id, entry_type, debit, credit, ref_type, ref_id, note, created_by)
  VALUES (v_partner_id, p_entry_type, v_debit, v_credit, p_ref_type, p_ref_id, p_note, p_created_by);

  SELECT balance INTO v_new_balance FROM partner_balances WHERE partner_balances.partner_id = v_partner_id;

  UPDATE app_data
  SET data = jsonb_set(
        data, '{partners}',
        (
          SELECT jsonb_agg(
            CASE WHEN (elem->>'id')::bigint = p_legacy_id
                 THEN jsonb_set(elem, '{invested}', to_jsonb(v_new_balance))
                 ELSE elem END
          )
          FROM jsonb_array_elements(data->'partners') elem
        )
      ),
      updated_at = now()
  WHERE id = 'main';

  RETURN QUERY SELECT v_partner_id, v_new_balance;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.partner_upsert_atomic(p_legacy_id bigint, p_name text, p_is_founder boolean, p_keep_pct numeric, p_color text DEFAULT NULL::text, p_avatar text DEFAULT NULL::text, p_initial_invested numeric DEFAULT NULL::numeric, p_partner_type text DEFAULT 'BUSINESS_OWNER'::text, p_investment_pct numeric DEFAULT NULL::numeric)
 RETURNS TABLE(partner_id bigint, is_new boolean)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id bigint; v_is_new boolean := false;
BEGIN
  IF p_investment_pct IS NOT NULL THEN
    IF p_partner_type = 'INVESTOR' AND (p_investment_pct < 10 OR p_investment_pct > 100) THEN
      RAISE EXCEPTION 'HAMKORLAR_V2_ERR: INVESTOR uchun investment_pct 10-100 oralig''ida bo''lishi shart (got %)', p_investment_pct USING ERRCODE='P0009';
    ELSIF p_partner_type <> 'INVESTOR' AND (p_investment_pct <= 0 OR p_investment_pct > 100) THEN
      RAISE EXCEPTION 'HAMKORLAR_V2_ERR: investment_pct 0dan katta va 100dan kichik/teng bo''lishi shart (got %)', p_investment_pct USING ERRCODE='P0009';
    END IF;
  END IF;
  SELECT id INTO v_id FROM partners WHERE legacy_id = p_legacy_id;
  IF v_id IS NULL THEN
    v_is_new := true;
    INSERT INTO partners (legacy_id, name, is_founder, keep_pct, color, avatar, partner_type, investment_pct)
    VALUES (p_legacy_id, p_name, p_is_founder, p_keep_pct, p_color, p_avatar, p_partner_type, p_investment_pct)
    RETURNING id INTO v_id;
    UPDATE app_data SET data = jsonb_set(
      COALESCE(data,'{}'::jsonb), '{partners}',
      COALESCE(data->'partners','[]'::jsonb) || jsonb_build_array(
        jsonb_build_object('id', p_legacy_id, 'name', p_name, 'isFounder', p_is_founder,
                            'keepPct', p_keep_pct, 'color', p_color, 'av', p_avatar,
                            'partnerType', p_partner_type, 'investmentPct', p_investment_pct,
                            'invested', COALESCE(p_initial_invested,0))
      ), true
    ), updated_at = now() WHERE id='main';
    IF COALESCE(p_initial_invested,0) <> 0 THEN
      PERFORM partner_ledger_add_atomic(p_legacy_id, 'capital_in', p_initial_invested, 'partner_create', NULL, 'Initial capital on partner creation');
    END IF;
  ELSE
    UPDATE partners SET name=p_name, is_founder=p_is_founder, keep_pct=p_keep_pct,
           color=COALESCE(p_color,color), avatar=COALESCE(p_avatar,avatar),
           partner_type=COALESCE(p_partner_type,partner_type),
           investment_pct=p_investment_pct, updated_at=now()
    WHERE id=v_id;
    UPDATE app_data SET data = jsonb_set(
      COALESCE(data,'{}'::jsonb), '{partners}',
      COALESCE((SELECT jsonb_agg(CASE WHEN (e->>'id')::bigint=p_legacy_id
                        THEN e || jsonb_build_object('name',p_name,'isFounder',p_is_founder,'keepPct',p_keep_pct,
                                                      'partnerType',p_partner_type,'investmentPct',p_investment_pct)
                        ELSE e END)
       FROM jsonb_array_elements(COALESCE(data->'partners','[]'::jsonb)) e), '[]'::jsonb), true
    ), updated_at = now() WHERE id='main';
  END IF;
  RETURN QUERY SELECT v_id, v_is_new;
END;
$function$
;

-- ────────────────────────────────────────────────────────────────────
-- 3e. HAMKORLAR V2 FUNKSIYALARI (2): oylik hisob va bekor qilish
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.partner_monthly_calc_atomic(p_period_legacy_id text, p_start date, p_end date, p_total_profit numeric, p_tasischi_expense numeric DEFAULT 0)
 RETURNS TABLE(period_id bigint, partners_affected integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_period_id bigint;
  v_total_pct numeric;
  v_missing_pct_count int;
  v_missing_names text;
  r RECORD;
  v_count int := 0;
BEGIN
  IF EXISTS (SELECT 1 FROM partner_periods WHERE legacy_id=p_period_legacy_id) THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: period legacy_id=% already processed (idempotent no-op required)', p_period_legacy_id USING ERRCODE='P0004';
  END IF;

  SELECT COUNT(*), STRING_AGG(name || ' (id=' || legacy_id || ')', ', ')
    INTO v_missing_pct_count, v_missing_names
    FROM partners WHERE status='active' AND investment_pct IS NULL;
  IF v_missing_pct_count > 0 THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: quyidagi % ta faol partnerda profit_pct belgilanmagan: % — monthly calc BLOCKED, hech qanday ledger yozilmadi', v_missing_pct_count, v_missing_names USING ERRCODE='P0011';
  END IF;

  SELECT COALESCE(SUM(investment_pct),0) INTO v_total_pct FROM partners WHERE status='active';

  IF v_total_pct < 100 THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: SUM(profit_pct)=% percent — 100 percentdan % percent kam (yetishmayotgan: % percent) — monthly calc BLOCKED, hech narsa taqsimlanmadi',
      v_total_pct, ROUND(100-v_total_pct,2), ROUND(100-v_total_pct,2) USING ERRCODE='P0012';
  ELSIF v_total_pct > 100 THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: SUM(profit_pct)=% percent — 100 percentdan % percent ortiq (oshib ketgan: % percent) — monthly calc BLOCKED, hech narsa taqsimlanmadi',
      v_total_pct, ROUND(v_total_pct-100,2), ROUND(v_total_pct-100,2) USING ERRCODE='P0013';
  END IF;

  CREATE TEMP TABLE _calc_rows ON COMMIT DROP AS
  SELECT p.id, p.legacy_id, p.investment_pct AS pct, p.partner_type,
         COALESCE(pb.balance,0) AS balance_before,
         ROUND(p_total_profit * p.investment_pct / 100, 2) AS distributed_amount
  FROM partners p LEFT JOIN partner_balances pb ON pb.partner_id=p.id WHERE p.status='active';

  INSERT INTO partner_periods (legacy_id, period_start, period_end, total_profit, total_capital_base, tasischi_expense, status)
  VALUES (p_period_legacy_id, p_start, p_end, p_total_profit, (SELECT COALESCE(SUM(balance_before),0) FROM _calc_rows), p_tasischi_expense, 'active')
  RETURNING id INTO v_period_id;

  FOR r IN SELECT * FROM _calc_rows LOOP
    IF r.distributed_amount <> 0 THEN
      INSERT INTO partner_ledger (partner_id, entry_type, debit, credit, ref_type, period_id, note, pct_snapshot)
      VALUES (r.id, 'profit_share', CASE WHEN r.distributed_amount<0 THEN -r.distributed_amount ELSE 0 END,
              CASE WHEN r.distributed_amount>=0 THEN r.distributed_amount ELSE 0 END, 'period', v_period_id,
              format('Oylik taqsimot %s-%s (profit_pct=%s%%)', p_start, p_end, r.pct), r.pct);
    END IF;
    v_count := v_count + 1;
  END LOOP;

  UPDATE app_data SET data = jsonb_set(
    data, '{partnerPeriods}',
    jsonb_build_array(jsonb_build_object(
      'id', p_period_legacy_id, 'start', p_start, 'end', p_end,
      'totalProfit', p_total_profit, 'tasischiExpense', p_tasischi_expense,
      'rows', (SELECT jsonb_agg(jsonb_build_object(
                 'pid', legacy_id, 'partnerType', partner_type, 'profitPct', pct,
                 'balanceBefore', balance_before, 'distributedAmount', distributed_amount))
               FROM _calc_rows)
    )) || COALESCE(data->'partnerPeriods','[]'::jsonb)
  ), updated_at=now() WHERE id='main';

  UPDATE app_data SET data = jsonb_set(
    data, '{partners}',
    (SELECT jsonb_agg(
       CASE WHEN cr.legacy_id IS NOT NULL THEN jsonb_set(e, '{invested}', to_jsonb(cr.balance_before+cr.distributed_amount))
            ELSE e END)
     FROM jsonb_array_elements(data->'partners') e
     LEFT JOIN _calc_rows cr ON cr.legacy_id = (e->>'id')::bigint)
  ), updated_at=now() WHERE id='main';

  RETURN QUERY SELECT v_period_id, v_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.partner_undo_period_atomic(p_period_legacy_id text, p_confirm boolean DEFAULT false)
 RETURNS TABLE(period_id bigint, reversed_entries integer)
 LANGUAGE plpgsql
AS $function$
DECLARE v_period_id bigint; v_status text; v_count int := 0; r RECORD;
BEGIN
  IF p_confirm IS NOT TRUE THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: undo requires explicit confirmation (p_confirm=true) — frontend must show warning modal first' USING ERRCODE='P0008';
  END IF;
  SELECT id, status INTO v_period_id, v_status FROM partner_periods WHERE legacy_id=p_period_legacy_id;
  IF v_period_id IS NULL THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: period legacy_id=% not found', p_period_legacy_id USING ERRCODE='P0006';
  END IF;
  IF v_status = 'legacy_snapshot' THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: period legacy_id=% is a legacy_snapshot — undo not allowed for pre-V2 historical data', p_period_legacy_id USING ERRCODE='P0010';
  END IF;
  IF v_status = 'undone' THEN
    RAISE EXCEPTION 'HAMKORLAR_V2_ERR: period legacy_id=% already undone (idempotent no-op required)', p_period_legacy_id USING ERRCODE='P0007';
  END IF;

  FOR r IN SELECT * FROM partner_ledger pl WHERE pl.period_id=v_period_id AND entry_type='profit_share' AND reversed_by IS NULL LOOP
    INSERT INTO partner_ledger (partner_id, entry_type, debit, credit, ref_type, period_id, note)
    VALUES (r.partner_id, 'reversal', r.credit, r.debit, 'period_undo', v_period_id, 'Undo: ' || COALESCE(r.note,''));
    v_count := v_count + 1;
  END LOOP;

  UPDATE partner_ledger orig SET reversed_by = rev.id
  FROM partner_ledger rev
  WHERE orig.period_id=v_period_id AND orig.entry_type='profit_share' AND orig.reversed_by IS NULL
    AND rev.period_id=v_period_id AND rev.entry_type='reversal' AND rev.partner_id=orig.partner_id
    AND rev.reversed_by IS NULL;

  UPDATE partner_periods SET status='undone' WHERE id=v_period_id;

  UPDATE app_data SET data = jsonb_set(
    data, '{partners}',
    (SELECT jsonb_agg(
       CASE WHEN pre.pid IS NOT NULL THEN jsonb_set(e, '{invested}', pre.invested)
            ELSE e END)
     FROM jsonb_array_elements(data->'partners') e
     LEFT JOIN (
       SELECT (row->>'pid')::bigint AS pid, (row->'invested') AS invested
       FROM jsonb_array_elements(
         (SELECT per->'rows' FROM jsonb_array_elements(data->'partnerPeriods') per WHERE (per->>'id')=p_period_legacy_id)
       ) row
     ) pre ON pre.pid = (e->>'id')::bigint)
  ), updated_at=now() WHERE id='main';

  UPDATE app_data SET data = jsonb_set(
    data, '{partnerPeriods}',
    (SELECT COALESCE(jsonb_agg(per), '[]'::jsonb) FROM jsonb_array_elements(data->'partnerPeriods') per WHERE (per->>'id')<>p_period_legacy_id)
  ), updated_at=now() WHERE id='main';

  RETURN QUERY SELECT v_period_id, v_count;
END;
$function$
;

-- ────────────────────────────────────────────────────────────────────
-- 4. VIEW'LAR VA RLS SIYOSATLARI
-- ────────────────────────────────────────────────────────────────────
create or replace view public.partner_balances with (security_invoker=true) as
 SELECT p.id AS partner_id,
    p.name,
    COALESCE(sum(l.credit) - sum(l.debit), 0::numeric) AS balance
   FROM partners p
     LEFT JOIN partner_ledger l ON l.partner_id = p.id
  GROUP BY p.id, p.name;
create or replace view public.partner_monthly_report_detail with (security_invoker=true) as
 SELECT pp.id AS period_id,
    pp.legacy_id AS period_legacy_id,
    pp.period_start,
    pp.period_end,
    pp.total_profit,
    pp.status AS period_status,
    p.id AS partner_id,
    p.legacy_id AS partner_legacy_id,
    p.name,
    p.is_founder,
    p.keep_pct,
    COALESCE(( SELECT sum(l2.credit) - sum(l2.debit)
           FROM partner_ledger l2
          WHERE l2.partner_id = p.id AND l2.created_at < (( SELECT min(partner_ledger.created_at) AS min
                   FROM partner_ledger
                  WHERE partner_ledger.period_id = pp.id))), 0::numeric) AS balance_before,
    pl.credit - pl.debit AS profit_share_net,
    pl.pct_snapshot,
    pl.entry_type,
    pl.note,
    pl.created_at AS ledger_entry_at,
    pl.reversed_by IS NOT NULL AS is_reversed
   FROM partner_periods pp
     JOIN partner_ledger pl ON pl.period_id = pp.id
     JOIN partners p ON p.id = pl.partner_id
  ORDER BY pp.period_start DESC, pl.credit DESC;
create or replace view public.partner_monthly_report_summary with (security_invoker=true) as
 SELECT pp.id AS period_id,
    pp.legacy_id,
    pp.period_start,
    pp.period_end,
    pp.total_profit,
    pp.total_capital_base,
    pp.tasischi_expense,
    COALESCE(sum(pl.credit) FILTER (WHERE pl.entry_type = 'profit_share'::text), 0::numeric) - COALESCE(sum(pl.debit) FILTER (WHERE pl.entry_type = 'profit_share'::text), 0::numeric) AS distributed_total,
    count(DISTINCT pl.partner_id) FILTER (WHERE pl.entry_type = 'profit_share'::text) AS partners_count,
    pp.status
   FROM partner_periods pp
     LEFT JOIN partner_ledger pl ON pl.period_id = pp.id
  GROUP BY pp.id, pp.legacy_id, pp.period_start, pp.period_end, pp.total_profit, pp.total_capital_base, pp.tasischi_expense, pp.status
  ORDER BY pp.period_start DESC;
drop policy if exists no_public_access on public.bot_sessions; create policy no_public_access on public.bot_sessions as permissive for all to public using (false) with check (false);
drop policy if exists dealer_read_catalog on public.catalog_products; create policy dealer_read_catalog on public.catalog_products as permissive for select to authenticated using ((filial IN ( SELECT dealers.filial
   FROM dealers
  WHERE (dealers.auth_user_id = auth.uid()))));
drop policy if exists dealer_insert_own_orders on public.dealer_orders; create policy dealer_insert_own_orders on public.dealer_orders as permissive for insert to authenticated with check (((dealer_id IN ( SELECT dealers.id
   FROM dealers
  WHERE (dealers.auth_user_id = auth.uid()))) AND (status = 'pending'::text)));
drop policy if exists dealer_read_own_orders on public.dealer_orders; create policy dealer_read_own_orders on public.dealer_orders as permissive for select to authenticated using ((dealer_id IN ( SELECT dealers.id
   FROM dealers
  WHERE (dealers.auth_user_id = auth.uid()))));
drop policy if exists dealer_read_payments on public.dealer_payments; create policy dealer_read_payments on public.dealer_payments as permissive for select to authenticated using ((dealer_id IN ( SELECT dealers.id
   FROM dealers
  WHERE (dealers.auth_user_id = auth.uid()))));
drop policy if exists dealer_read_sales on public.dealer_sales; create policy dealer_read_sales on public.dealer_sales as permissive for select to authenticated using ((dealer_id IN ( SELECT dealers.id
   FROM dealers
  WHERE (dealers.auth_user_id = auth.uid()))));
drop policy if exists dealer_read_stock on public.dealer_stock; create policy dealer_read_stock on public.dealer_stock as permissive for select to authenticated using ((dealer_id IN ( SELECT dealers.id
   FROM dealers
  WHERE (dealers.auth_user_id = auth.uid()))));
drop policy if exists dealer_read_self on public.dealers; create policy dealer_read_self on public.dealers as permissive for select to authenticated using ((auth_user_id = auth.uid()));
drop policy if exists no_public_access on public.login_security; create policy no_public_access on public.login_security as permissive for all to public using (false) with check (false);
drop policy if exists no_public_access on public.partner_ledger_legacy_history; create policy no_public_access on public.partner_ledger_legacy_history as permissive for all to public using (false) with check (false);
drop policy if exists no_public_access on public.partner_ledger; create policy no_public_access on public.partner_ledger as permissive for all to public using (false) with check (false);
drop policy if exists no_public_access on public.partner_payments; create policy no_public_access on public.partner_payments as permissive for all to public using (false) with check (false);
drop policy if exists no_public_access on public.partner_periods; create policy no_public_access on public.partner_periods as permissive for all to public using (false) with check (false);
drop policy if exists no_public_access on public.partners; create policy no_public_access on public.partners as permissive for all to public using (false) with check (false);
drop policy if exists product_images_delete on storage.objects;  -- v10: anon yozishi yopildi
-- v10: rasm saqlagichiga yozish/o'zgartirish/o'chirish — faqat faol xodim (diller va anon emas)
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;
create or replace function private.is_active_staff()
 returns boolean
 language sql
 stable
 security definer
 set search_path = ''
as $$
  select exists (
    select 1 from public.staff s
    where s.auth_user_id = (select auth.uid()) and s.active
  );
$$;
revoke all on function private.is_active_staff() from public, anon;
grant execute on function private.is_active_staff() to authenticated, service_role;
drop policy if exists product_images_write_auth on storage.objects; create policy product_images_write_auth on storage.objects as permissive for insert to authenticated with check ((bucket_id = 'product-images'::text) and (select private.is_active_staff()));
drop policy if exists product_images_update_auth on storage.objects; create policy product_images_update_auth on storage.objects as permissive for update to authenticated using ((bucket_id = 'product-images'::text) and (select private.is_active_staff())) with check ((bucket_id = 'product-images'::text) and (select private.is_active_staff()));
drop policy if exists product_images_delete_auth on storage.objects; create policy product_images_delete_auth on storage.objects as permissive for delete to authenticated using ((bucket_id = 'product-images'::text) and (select private.is_active_staff()));
drop policy if exists product_images_read on storage.objects; create policy product_images_read on storage.objects as permissive for select to anon using ((bucket_id = 'product-images'::text));
drop policy if exists product_images_read_auth on storage.objects; create policy product_images_read_auth on storage.objects as permissive for select to authenticated using ((bucket_id = 'product-images'::text));
drop policy if exists product_images_update on storage.objects;  -- v10: anon yozishi yopildi
drop policy if exists product_images_write on storage.objects;  -- v10: anon yozishi yopildi

-- ────────────────────────────────────────────────────────────────────
-- 5. RUXSATLAR (GRANT), SAQLAGICH, RLS-AVTO TRIGGER
-- ────────────────────────────────────────────────────────────────────
-- Supabase yangi loyihada barcha jadval/funksiyalarga anon/authenticated'ga TO'LIQ ruxsat beradi.
-- Production'dagi kabi (P2 xavfsizlik) — avval hammasi olinadi, keyin faqat kerakli ruxsatlar qaytariladi.
revoke all on public.app_data_branches, public.app_data, public.batches, public.bot_sessions, public.cashbox_balances, public.cashbox_transactions, public.catalog_products, public.customer_balances, public.customer_debt_payments, public.dealer_audit_log, public.dealer_orders, public.dealer_payments, public.dealer_sales, public.dealer_stock_moves, public.dealer_stock, public.dealers, public.home_withdrawals, public.idempotency_keys, public.login_security, public.partner_balances, public.partner_ledger_legacy_history, public.partner_ledger, public.partner_monthly_report_detail, public.partner_monthly_report_summary, public.partner_payments, public.partner_periods, public.partners, public.permissions, public.role_permissions, public.roles, public.sales, public.staff_audit_log, public.staff_roles, public.staff, public.supplier_balances, public.supplier_payments from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.app_data_branches to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.app_data to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.batches to service_role;
grant delete, insert, select, update on public.bot_sessions to anon;
grant delete, insert, select, update on public.bot_sessions to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.bot_sessions to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.cashbox_balances to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.cashbox_transactions to service_role;
grant delete, insert, select, update on public.catalog_products to anon;
grant delete, insert, select, update on public.catalog_products to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.catalog_products to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.customer_balances to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.customer_debt_payments to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.dealer_audit_log to service_role;
grant delete, insert, select, update on public.dealer_orders to anon;
grant delete, insert, select, update on public.dealer_orders to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.dealer_orders to service_role;
grant delete, insert, select, update on public.dealer_payments to anon;
grant delete, insert, select, update on public.dealer_payments to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.dealer_payments to service_role;
grant delete, insert, select, update on public.dealer_sales to anon;
grant delete, insert, select, update on public.dealer_sales to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.dealer_sales to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.dealer_stock_moves to service_role;
grant delete, insert, select, update on public.dealer_stock to anon;
grant delete, insert, select, update on public.dealer_stock to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.dealer_stock to service_role;
grant delete, insert, select, update on public.dealers to anon;
grant delete, insert, select, update on public.dealers to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.dealers to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.home_withdrawals to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.idempotency_keys to service_role;
grant delete, insert, select, update on public.login_security to anon;
grant delete, insert, select, update on public.login_security to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.login_security to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.partner_balances to anon;
grant delete, insert, references, select, trigger, truncate, update on public.partner_balances to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_balances to service_role;
grant delete, insert, select, update on public.partner_ledger_legacy_history to anon;
grant delete, insert, select, update on public.partner_ledger_legacy_history to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_ledger_legacy_history to service_role;
grant delete, insert, select, update on public.partner_ledger to anon;
grant delete, insert, select, update on public.partner_ledger to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_ledger to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.partner_monthly_report_detail to anon;
grant delete, insert, references, select, trigger, truncate, update on public.partner_monthly_report_detail to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_monthly_report_detail to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.partner_monthly_report_summary to anon;
grant delete, insert, references, select, trigger, truncate, update on public.partner_monthly_report_summary to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_monthly_report_summary to service_role;
grant delete, insert, select, update on public.partner_payments to anon;
grant delete, insert, select, update on public.partner_payments to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_payments to service_role;
grant delete, insert, select, update on public.partner_periods to anon;
grant delete, insert, select, update on public.partner_periods to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partner_periods to service_role;
grant delete, insert, select, update on public.partners to anon;
grant delete, insert, select, update on public.partners to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.partners to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.permissions to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.role_permissions to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.roles to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.sales to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.staff_audit_log to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.staff_roles to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.staff to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.supplier_balances to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.supplier_payments to service_role;
grant execute on function public.dealer_sale_atomic(p_dealer_id bigint, p_items jsonb, p_sale_date date) to service_role;
grant execute on function public.login_check_lock(p_login text) to anon;
grant execute on function public.login_check_lock(p_login text) to authenticated;
grant execute on function public.login_check_lock(p_login text) to public;
grant execute on function public.login_check_lock(p_login text) to service_role;
grant execute on function public.login_record_failure(p_login text) to anon;
grant execute on function public.login_record_failure(p_login text) to authenticated;
grant execute on function public.login_record_failure(p_login text) to public;
grant execute on function public.login_record_failure(p_login text) to service_role;
grant execute on function public.login_record_success(p_login text) to anon;
grant execute on function public.login_record_success(p_login text) to authenticated;
grant execute on function public.login_record_success(p_login text) to public;
grant execute on function public.login_record_success(p_login text) to service_role;
grant execute on function public.partner_archive_atomic(p_legacy_id bigint) to anon;
grant execute on function public.partner_archive_atomic(p_legacy_id bigint) to authenticated;
grant execute on function public.partner_archive_atomic(p_legacy_id bigint) to public;
grant execute on function public.partner_archive_atomic(p_legacy_id bigint) to service_role;
grant execute on function public.partner_ledger_add_atomic(p_legacy_id bigint, p_entry_type text, p_amount numeric, p_ref_type text, p_ref_id text, p_note text, p_created_by text) to anon;
grant execute on function public.partner_ledger_add_atomic(p_legacy_id bigint, p_entry_type text, p_amount numeric, p_ref_type text, p_ref_id text, p_note text, p_created_by text) to authenticated;
grant execute on function public.partner_ledger_add_atomic(p_legacy_id bigint, p_entry_type text, p_amount numeric, p_ref_type text, p_ref_id text, p_note text, p_created_by text) to public;
grant execute on function public.partner_ledger_add_atomic(p_legacy_id bigint, p_entry_type text, p_amount numeric, p_ref_type text, p_ref_id text, p_note text, p_created_by text) to service_role;
grant execute on function public.partner_monthly_calc_atomic(p_period_legacy_id text, p_start date, p_end date, p_total_profit numeric, p_tasischi_expense numeric) to anon;
grant execute on function public.partner_monthly_calc_atomic(p_period_legacy_id text, p_start date, p_end date, p_total_profit numeric, p_tasischi_expense numeric) to authenticated;
grant execute on function public.partner_monthly_calc_atomic(p_period_legacy_id text, p_start date, p_end date, p_total_profit numeric, p_tasischi_expense numeric) to public;
grant execute on function public.partner_monthly_calc_atomic(p_period_legacy_id text, p_start date, p_end date, p_total_profit numeric, p_tasischi_expense numeric) to service_role;
grant execute on function public.partner_undo_period_atomic(p_period_legacy_id text, p_confirm boolean) to anon;
grant execute on function public.partner_undo_period_atomic(p_period_legacy_id text, p_confirm boolean) to authenticated;
grant execute on function public.partner_undo_period_atomic(p_period_legacy_id text, p_confirm boolean) to public;
grant execute on function public.partner_undo_period_atomic(p_period_legacy_id text, p_confirm boolean) to service_role;
grant execute on function public.partner_upsert_atomic(p_legacy_id bigint, p_name text, p_is_founder boolean, p_keep_pct numeric, p_color text, p_avatar text, p_initial_invested numeric, p_partner_type text, p_investment_pct numeric) to anon;
grant execute on function public.partner_upsert_atomic(p_legacy_id bigint, p_name text, p_is_founder boolean, p_keep_pct numeric, p_color text, p_avatar text, p_initial_invested numeric, p_partner_type text, p_investment_pct numeric) to authenticated;
grant execute on function public.partner_upsert_atomic(p_legacy_id bigint, p_name text, p_is_founder boolean, p_keep_pct numeric, p_color text, p_avatar text, p_initial_invested numeric, p_partner_type text, p_investment_pct numeric) to public;
grant execute on function public.partner_upsert_atomic(p_legacy_id bigint, p_name text, p_is_founder boolean, p_keep_pct numeric, p_color text, p_avatar text, p_initial_invested numeric, p_partner_type text, p_investment_pct numeric) to service_role;
grant execute on function public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text) to authenticated;
grant execute on function public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text) to service_role;
grant execute on function public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric) to authenticated;
grant execute on function public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric) to service_role;
grant execute on function public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric, p_optim_price numeric) to authenticated;
grant execute on function public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric, p_optim_price numeric) to service_role;
grant execute on function public.rls_auto_enable() to service_role;
grant execute on function public.sale_checkout_atomic(p_filial text, p_items jsonb, p_disc_pct numeric, p_paid_usd numeric, p_cust_id bigint, p_box_id bigint, p_box_amount_native numeric, p_inv text) to service_role;
grant execute on function public.sale_checkout_atomic_v2(p_filial text, p_items jsonb, p_disc_pct numeric, p_paid_usd numeric, p_cust_id bigint, p_box_payments jsonb, p_inv text) to service_role;

-- Mahsulot rasmlari saqlagichi (Storage bucket) — ochiq o'qish
insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

-- Yangi jadval yaratilganda RLS avtomatik yoqiladi (production'dagi ensure_rls)
do $$ begin
  if not exists (select 1 from pg_event_trigger where evtname = 'ensure_rls') then
    create event trigger ensure_rls on ddl_command_end when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') execute function public.rls_auto_enable();
  end if;
end $$;

-- ────────────────────────────────────────────────────────────────────
-- 6. BOSHLANG'ICH MA'LUMOT: rollar va ruxsatlar
-- ────────────────────────────────────────────────────────────────────
-- Boshlang'ich ma'lumot: rollar, ruxsatlar va ularning bog'lanishi (production bilan bir xil).

-- Takroriy ishga tushirish xavfsiz (on conflict do nothing).

-- Asosiy ma'lumot bloki (ilova birinchi saqlashda to'ldiradi).
insert into public.app_data (id, data) values ('main', '{"partners": [], "partnerPeriods": []}'::jsonb) on conflict (id) do nothing;

insert into public.roles (key, name, description, is_system) values
  ('accountant', 'Hisobchi', 'Hisobchi, Kassalar, Xarajatlar, Hisobot, Hamkorlar', false),
  ('administrator', 'Administrator', 'Deyarli barcha huquqlar, jumladan rollarni boshqarish', true),
  ('branch_manager', 'Filial menejeri', 'Filial menejeri, Dashboard, Savdo, Sklad, Moliya', false),
  ('cashier', 'Kassir', 'Kassir, Dashboard, Kassa, Savdo', false),
  ('dealer', 'Diller', 'Diller, alohida portal, admin panelga kirmaydi', true),
  ('employee', 'Xodim', 'Oddiy xodim, yengil sotuvchi portali', false),
  ('owner', 'Korxona egasi', 'Egasi, barcha huquqlarga ega, tizim roli, ochirib bolmaydi', true),
  ('sales_manager', 'Savdo menejeri', 'Savdo menejeri, Savdo, Mijozlar, Hisobot', false),
  ('warehouse_manager', 'Ombor mudiri', 'Ombor mudiri, Mahsulotlar, Ombor, Kirim', false)
on conflict (key) do nothing;

insert into public.permissions (key, module, label) values
  ('dashboard.view', 'dashboard', 'Bosh sahifani korish'),
  ('dillerlar.manage', 'dillerlar', 'Diller qoshish/tahrirlash/ochirish'),
  ('dillerlar.orders', 'dillerlar', 'Diller buyurtmalarini tasdiqlash/rad etish'),
  ('dillerlar.view', 'dillerlar', 'Dillerlar bolimini korish'),
  ('hamkorlar.calc', 'hamkorlar', 'Oylik foyda taqsimotini hisoblash'),
  ('hamkorlar.edit', 'hamkorlar', 'Hamkor ma''lumotini tahrirlash'),
  ('hamkorlar.view', 'hamkorlar', 'Hamkorlarni korish'),
  ('hisobot.export', 'hisobot', 'Excel eksport qilish'),
  ('hisobot.view', 'hisobot', 'Hisobotlarni korish'),
  ('kassalar.transact', 'kassalar', 'Kirim/Chiqim/Kochirish qilish'),
  ('kassalar.view', 'kassalar', 'Kassalarni korish'),
  ('kirim.create', 'kirim', 'Yangi kirim qilish'),
  ('kirim.view', 'kirim', 'Import/Kirimni korish'),
  ('mahsulotlar.create', 'mahsulotlar', 'Mahsulot qoshish'),
  ('mahsulotlar.delete', 'mahsulotlar', 'Mahsulotni ochirish'),
  ('mahsulotlar.edit', 'mahsulotlar', 'Mahsulotni tahrirlash'),
  ('mahsulotlar.view', 'mahsulotlar', 'Mahsulotlarni korish'),
  ('mijozlar.debt_payment', 'mijozlar', 'Mijoz qarzini qabul qilish'),
  ('mijozlar.edit', 'mijozlar', 'Mijoz malumotini tahrirlash'),
  ('mijozlar.view', 'mijozlar', 'Mijozlarni korish'),
  ('ombor.edit', 'ombor', 'Ombor/partiya ma''lumotini tahrirlash'),
  ('ombor.view', 'ombor', 'Omborni (FIFO) korish'),
  ('qaytarish.create', 'qaytarish', 'Qaytarish qilish'),
  ('qaytarish.view', 'qaytarish', 'Qaytarishlarni korish'),
  ('rollar.manage', 'rollar', 'Rol va ruxsatlarni boshqarish'),
  ('savdo.create', 'savdo', 'Yangi savdo yaratish'),
  ('savdo.delete', 'savdo', 'Savdoni ochirish'),
  ('savdo.edit', 'savdo', 'Savdoni tahrirlash'),
  ('savdo.view', 'savdo', 'Savdo bolimini korish'),
  ('sotuvchilar.manage', 'sotuvchilar', 'Xodim qoshish/tahrirlash/ochirish'),
  ('sotuvchilar.view', 'sotuvchilar', 'Xodimlar royxatini korish'),
  ('sozlamalar.edit', 'sozlamalar', 'Sozlamalarni ozgartirish'),
  ('sozlamalar.view', 'sozlamalar', 'Sozlamalarni korish'),
  ('taminotchilar.edit', 'taminotchilar', 'Ta''minotchi ma''lumotini tahrirlash'),
  ('taminotchilar.view', 'taminotchilar', 'Taminotchilarni korish'),
  ('xarajatlar.create', 'xarajatlar', 'Xarajat qoshish'),
  ('xarajatlar.view', 'xarajatlar', 'Xarajatlarni korish')
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from (values
  ('accountant', 'dashboard.view'),
  ('accountant', 'hamkorlar.calc'),
  ('accountant', 'hamkorlar.edit'),
  ('accountant', 'hamkorlar.view'),
  ('accountant', 'hisobot.export'),
  ('accountant', 'hisobot.view'),
  ('accountant', 'kassalar.transact'),
  ('accountant', 'kassalar.view'),
  ('accountant', 'taminotchilar.edit'),
  ('accountant', 'taminotchilar.view'),
  ('accountant', 'xarajatlar.create'),
  ('accountant', 'xarajatlar.view'),
  ('administrator', 'dashboard.view'),
  ('administrator', 'dillerlar.manage'),
  ('administrator', 'dillerlar.orders'),
  ('administrator', 'dillerlar.view'),
  ('administrator', 'hamkorlar.calc'),
  ('administrator', 'hamkorlar.edit'),
  ('administrator', 'hamkorlar.view'),
  ('administrator', 'hisobot.export'),
  ('administrator', 'hisobot.view'),
  ('administrator', 'kassalar.transact'),
  ('administrator', 'kassalar.view'),
  ('administrator', 'kirim.create'),
  ('administrator', 'kirim.view'),
  ('administrator', 'mahsulotlar.create'),
  ('administrator', 'mahsulotlar.delete'),
  ('administrator', 'mahsulotlar.edit'),
  ('administrator', 'mahsulotlar.view'),
  ('administrator', 'mijozlar.debt_payment'),
  ('administrator', 'mijozlar.edit'),
  ('administrator', 'mijozlar.view'),
  ('administrator', 'ombor.edit'),
  ('administrator', 'ombor.view'),
  ('administrator', 'qaytarish.create'),
  ('administrator', 'qaytarish.view'),
  ('administrator', 'rollar.manage'),
  ('administrator', 'savdo.create'),
  ('administrator', 'savdo.delete'),
  ('administrator', 'savdo.edit'),
  ('administrator', 'savdo.view'),
  ('administrator', 'sotuvchilar.manage'),
  ('administrator', 'sotuvchilar.view'),
  ('administrator', 'sozlamalar.edit'),
  ('administrator', 'sozlamalar.view'),
  ('administrator', 'taminotchilar.edit'),
  ('administrator', 'taminotchilar.view'),
  ('administrator', 'xarajatlar.create'),
  ('administrator', 'xarajatlar.view'),
  ('branch_manager', 'dashboard.view'),
  ('branch_manager', 'hisobot.view'),
  ('branch_manager', 'kassalar.transact'),
  ('branch_manager', 'kassalar.view'),
  ('branch_manager', 'kirim.view'),
  ('branch_manager', 'mahsulotlar.view'),
  ('branch_manager', 'mijozlar.debt_payment'),
  ('branch_manager', 'mijozlar.view'),
  ('branch_manager', 'ombor.edit'),
  ('branch_manager', 'ombor.view'),
  ('branch_manager', 'qaytarish.create'),
  ('branch_manager', 'qaytarish.view'),
  ('branch_manager', 'savdo.create'),
  ('branch_manager', 'savdo.edit'),
  ('branch_manager', 'savdo.view'),
  ('branch_manager', 'sotuvchilar.manage'),
  ('branch_manager', 'xarajatlar.create'),
  ('branch_manager', 'xarajatlar.view'),
  ('cashier', 'dashboard.view'),
  ('cashier', 'kassalar.transact'),
  ('cashier', 'kassalar.view'),
  ('cashier', 'mijozlar.debt_payment'),
  ('cashier', 'savdo.create'),
  ('cashier', 'savdo.view'),
  ('employee', 'dashboard.view'),
  ('employee', 'dillerlar.manage'),
  ('employee', 'dillerlar.orders'),
  ('employee', 'dillerlar.view'),
  ('owner', 'dashboard.view'),
  ('owner', 'dillerlar.manage'),
  ('owner', 'dillerlar.orders'),
  ('owner', 'dillerlar.view'),
  ('owner', 'hamkorlar.calc'),
  ('owner', 'hamkorlar.edit'),
  ('owner', 'hamkorlar.view'),
  ('owner', 'hisobot.export'),
  ('owner', 'hisobot.view'),
  ('owner', 'kassalar.transact'),
  ('owner', 'kassalar.view'),
  ('owner', 'kirim.create'),
  ('owner', 'kirim.view'),
  ('owner', 'mahsulotlar.create'),
  ('owner', 'mahsulotlar.delete'),
  ('owner', 'mahsulotlar.edit'),
  ('owner', 'mahsulotlar.view'),
  ('owner', 'mijozlar.debt_payment'),
  ('owner', 'mijozlar.edit'),
  ('owner', 'mijozlar.view'),
  ('owner', 'ombor.edit'),
  ('owner', 'ombor.view'),
  ('owner', 'qaytarish.create'),
  ('owner', 'qaytarish.view'),
  ('owner', 'rollar.manage'),
  ('owner', 'savdo.create'),
  ('owner', 'savdo.delete'),
  ('owner', 'savdo.edit'),
  ('owner', 'savdo.view'),
  ('owner', 'sotuvchilar.manage'),
  ('owner', 'sotuvchilar.view'),
  ('owner', 'sozlamalar.edit'),
  ('owner', 'sozlamalar.view'),
  ('owner', 'taminotchilar.edit'),
  ('owner', 'taminotchilar.view'),
  ('owner', 'xarajatlar.create'),
  ('owner', 'xarajatlar.view'),
  ('sales_manager', 'dashboard.view'),
  ('sales_manager', 'hisobot.view'),
  ('sales_manager', 'mijozlar.debt_payment'),
  ('sales_manager', 'mijozlar.edit'),
  ('sales_manager', 'mijozlar.view'),
  ('sales_manager', 'qaytarish.create'),
  ('sales_manager', 'qaytarish.view'),
  ('sales_manager', 'savdo.create'),
  ('sales_manager', 'savdo.edit'),
  ('sales_manager', 'savdo.view'),
  ('warehouse_manager', 'dashboard.view'),
  ('warehouse_manager', 'kirim.create'),
  ('warehouse_manager', 'kirim.view'),
  ('warehouse_manager', 'mahsulotlar.create'),
  ('warehouse_manager', 'mahsulotlar.edit'),
  ('warehouse_manager', 'mahsulotlar.view'),
  ('warehouse_manager', 'ombor.edit'),
  ('warehouse_manager', 'ombor.view')
) v(rk, pk) join public.roles r on r.key = v.rk join public.permissions p on p.key = v.pk
on conflict do nothing;

-- ────────────────────────────────────────────────────────────────────
-- 7. v10 (23-migratsiya): FIRMA KASSA, diller savdosi xavfsizligi, hamkor funksiyalari ruxsati
-- (supabase-migration-23-v10-firma-kassa.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- Migratsiya 23 (v10, 2026-10-01) — FIRMA KASSA + diller savdosi xavfsizligi
-- Takroriy ishga tushirish xavfsiz. Mavjud ma'lumot o'chirilmaydi.
--
-- 1) FIRMA KASSA — korxona darajasidagi markaziy kassa (filial kassalaridan ALOHIDA).
--    • Hisob valyutasi FAQAT USD yoki UZS (CNY — faqat Kirim kiritish valyutasi,
--      hisob valyutasi bo'la olmaydi — CHECK cheklovi bilan).
--    • Qoldiq hech qachon manfiy bo'lmaydi (CHECK + funksiya ichida qulflab tekshirish).
--    • Har bir harakat — bitta tranzaksiyada: qoldiq qatori FOR UPDATE bilan
--      qulflanadi, yangilanadi va ledger'ga yoziladi (yarim holat yo'q).
--    • Idempotency: ledger.idem_key UNIQUE — bir xil so'rov ikki marta kelsa,
--      birinchi natija qaytadi, pul ikki marta harakatlanmaydi.
--    • Avans: berilgan (advance_give) − qaytarilgan (advance_repay); qaytarish
--      qolgan avansdan oshmaydi.
--    • Hamkor (ta'sischi) pul olishi — 'partner_withdrawal' (maosh EMAS).
--    • Kirish: faqat server (service_role) — brauzerdan to'g'ridan-to'g'ri yo'q.
-- 2) record_dealer_sale — qarz uchun optim narx va ballar endi SERVERDA
--    hisoblanadi (avval diller o'zi yuborardi: optim_price=0 → qarz yozilmasdi);
--    ombor qoldig'i qulflab o'qiladi (parallel savdo ikki marta sotolmaydi);
--    eski 5/6 argumentli variantlar diller uchun yopildi.
-- 3) Hamkor funksiyalari (partner_*_atomic) — anon/authenticated'dan EXECUTE
--    olib tashlandi (ularni faqat server chaqiradi; RLS baribir to'sardi —
--    bu qo'shimcha himoya qatlami).
-- 4) Ruxsatlar: firma_kassa.view, firma_kassa.transact.
-- ════════════════════════════════════════════════════════════════════

-- ── 1. FIRMA KASSA: jadvallar ──────────────────────────────────────────
create table if not exists public.firma_kassa_balance (
  currency text primary key,
  balance numeric(18,2) not null default 0,
  updated_at timestamp with time zone not null default now(),
  constraint firma_kassa_balance_currency_chk check (currency in ('USD','UZS')),
  constraint firma_kassa_balance_nonneg_chk check (balance >= 0)
);
insert into public.firma_kassa_balance (currency) values ('USD'), ('UZS') on conflict (currency) do nothing;

create table if not exists public.firma_kassa_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  currency text not null,
  direction text not null,
  amount numeric(18,2) not null,
  balance_after numeric(18,2) not null,
  op_type text not null,
  counterparty_type text,
  counterparty_id text,
  counterparty_name text,
  filial text,
  ref_type text,
  ref_id text,
  note text,
  staff_id bigint,
  staff_name text,
  idem_key text,
  constraint firma_kassa_ledger_idem_key_key unique (idem_key),
  constraint firma_kassa_ledger_currency_chk check (currency in ('USD','UZS')),
  constraint firma_kassa_ledger_amount_chk check (amount > 0),
  constraint firma_kassa_ledger_balance_chk check (balance_after >= 0),
  constraint firma_kassa_ledger_cp_chk check (counterparty_type is null or counterparty_type in ('branch','supplier','staff','partner','dealer','other')),
  constraint firma_kassa_ledger_op_chk check (
    (direction = 'in'  and op_type in ('deposit','branch_in','advance_repay','adjust_in')) or
    (direction = 'out' and op_type in ('withdraw','branch_out','advance_give','kirim_payment','partner_withdrawal','adjust_out'))
  ),
  constraint firma_kassa_ledger_note_len check (coalesce(length(note),0) <= 500 and coalesce(length(counterparty_name),0) <= 200)
);
create index if not exists idx_fk_ledger_created on public.firma_kassa_ledger (created_at desc);
create index if not exists idx_fk_ledger_cp on public.firma_kassa_ledger (counterparty_type, counterparty_id, currency) where op_type in ('advance_give','advance_repay');

alter table public.firma_kassa_balance enable row level security;
alter table public.firma_kassa_ledger enable row level security;
revoke all on public.firma_kassa_balance, public.firma_kassa_ledger from anon, authenticated;
grant select, insert, update on public.firma_kassa_balance to service_role;
grant select, insert on public.firma_kassa_ledger to service_role;
grant usage on sequence public.firma_kassa_ledger_id_seq to service_role;

-- ── 1b. FIRMA KASSA: yagona yozish yo'li ───────────────────────────────
create or replace function public._fk_cash_move(
  p_currency text, p_direction text, p_amount numeric, p_op_type text,
  p_counterparty_type text default null, p_counterparty_id text default null, p_counterparty_name text default null,
  p_filial text default null, p_ref_type text default null, p_ref_id text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null, p_idem_key text default null)
 returns public.firma_kassa_ledger
 language plpgsql
 set search_path = ''
as $$
declare
  v_amt numeric;
  v_bal numeric;
  v_row public.firma_kassa_ledger;
begin
  if p_idem_key is not null then
    select * into v_row from public.firma_kassa_ledger where idem_key = p_idem_key;
    if found then return v_row; end if;
  end if;
  if p_currency is null or p_currency not in ('USD','UZS') then
    raise exception 'FIRMA_KASSA: valyuta faqat USD yoki UZS bo''lishi mumkin (CNY hisob valyutasi emas)' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 10000000000000 then
    raise exception 'FIRMA_KASSA: summa musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  v_amt := round(p_amount, 2);
  if v_amt <= 0 then
    raise exception 'FIRMA_KASSA: summa juda kichik' using errcode = 'P0001';
  end if;

  select balance into v_bal from public.firma_kassa_balance where currency = p_currency for update;
  if not found then
    insert into public.firma_kassa_balance (currency, balance) values (p_currency, 0) on conflict (currency) do nothing;
    select balance into v_bal from public.firma_kassa_balance where currency = p_currency for update;
  end if;

  if p_direction = 'out' then
    if v_bal < v_amt then
      raise exception 'FIRMA_KASSA: mablag'' yetarli emas (qoldiq %, so''ralgan %)', v_bal, v_amt using errcode = 'P0001';
    end if;
    v_bal := v_bal - v_amt;
  elsif p_direction = 'in' then
    v_bal := v_bal + v_amt;
  else
    raise exception 'FIRMA_KASSA: yo''nalish noto''g''ri' using errcode = 'P0001';
  end if;

  update public.firma_kassa_balance set balance = v_bal, updated_at = now() where currency = p_currency;
  insert into public.firma_kassa_ledger
    (currency, direction, amount, balance_after, op_type, counterparty_type, counterparty_id, counterparty_name,
     filial, ref_type, ref_id, note, staff_id, staff_name, idem_key)
  values
    (p_currency, p_direction, v_amt, v_bal, p_op_type, p_counterparty_type, p_counterparty_id, left(p_counterparty_name, 200),
     p_filial, p_ref_type, p_ref_id, left(p_note, 500), p_staff_id, left(p_staff_name, 200), p_idem_key)
  returning * into v_row;
  return v_row;
exception when unique_violation then
  -- Parallel bir xil so'rov (idem_key) boshqa tranzaksiyada allaqachon yozildi
  select * into v_row from public.firma_kassa_ledger where idem_key = p_idem_key;
  if found then return v_row; end if;
  raise;
end;
$$;

create or replace function public.firma_kassa_advance_outstanding(p_currency text, p_counterparty_type text, p_counterparty_id text)
 returns numeric
 language sql
 stable
 set search_path = ''
as $$
  select coalesce(sum(case when op_type = 'advance_give' then amount else -amount end), 0)
  from public.firma_kassa_ledger
  where currency = p_currency and counterparty_type = p_counterparty_type and counterparty_id = p_counterparty_id
    and op_type in ('advance_give','advance_repay');
$$;

create or replace function public.firma_kassa_give_advance(
  p_currency text, p_amount numeric, p_counterparty_type text, p_counterparty_id text, p_counterparty_name text,
  p_note text default null, p_staff_id bigint default null, p_staff_name text default null, p_idem_key text default null)
 returns public.firma_kassa_ledger
 language plpgsql
 set search_path = ''
as $$
begin
  if p_counterparty_type is null or p_counterparty_type not in ('branch','supplier','staff','dealer','other') or coalesce(p_counterparty_id,'') = '' then
    raise exception 'FIRMA_KASSA: avans oluvchi ko''rsatilishi shart' using errcode = 'P0001';
  end if;
  return public._fk_cash_move(p_currency, 'out', p_amount, 'advance_give', p_counterparty_type, p_counterparty_id, p_counterparty_name,
                              null, null, null, p_note, p_staff_id, p_staff_name, p_idem_key);
end;
$$;

create or replace function public.firma_kassa_repay_advance(
  p_currency text, p_amount numeric, p_counterparty_type text, p_counterparty_id text, p_counterparty_name text,
  p_note text default null, p_staff_id bigint default null, p_staff_name text default null, p_idem_key text default null)
 returns public.firma_kassa_ledger
 language plpgsql
 set search_path = ''
as $$
declare
  v_row public.firma_kassa_ledger;
  v_out numeric;
begin
  if p_idem_key is not null then
    select * into v_row from public.firma_kassa_ledger where idem_key = p_idem_key;
    if found then return v_row; end if;
  end if;
  if p_counterparty_type is null or coalesce(p_counterparty_id,'') = '' then
    raise exception 'FIRMA_KASSA: avans egasi ko''rsatilishi shart' using errcode = 'P0001';
  end if;
  -- Bir xil avans egasi bo'yicha parallel qaytarishlar navbatga qo'yiladi
  perform pg_advisory_xact_lock(hashtext('fk_adv:' || p_currency || ':' || p_counterparty_type || ':' || p_counterparty_id));
  v_out := public.firma_kassa_advance_outstanding(p_currency, p_counterparty_type, p_counterparty_id);
  if p_amount is null or round(p_amount, 2) > v_out then
    raise exception 'FIRMA_KASSA: qaytarish summasi qolgan avansdan (%) oshib ketdi', v_out using errcode = 'P0001';
  end if;
  return public._fk_cash_move(p_currency, 'in', p_amount, 'advance_repay', p_counterparty_type, p_counterparty_id, p_counterparty_name,
                              null, null, null, p_note, p_staff_id, p_staff_name, p_idem_key);
end;
$$;

create or replace function public.firma_kassa_get_balance()
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object(
    'balances', coalesce((select jsonb_object_agg(currency, balance) from public.firma_kassa_balance), '{}'::jsonb),
    'advances', coalesce((
      select jsonb_agg(a order by a->>'counterparty_name') from (
        select jsonb_build_object('currency', currency, 'counterparty_type', counterparty_type, 'counterparty_id', counterparty_id,
                                  'counterparty_name', max(counterparty_name),
                                  'outstanding', sum(case when op_type = 'advance_give' then amount else -amount end)) a
        from public.firma_kassa_ledger
        where op_type in ('advance_give','advance_repay')
        group by currency, counterparty_type, counterparty_id
        having sum(case when op_type = 'advance_give' then amount else -amount end) > 0
      ) t), '[]'::jsonb)
  );
$$;

create or replace function public.kirim_firma_kassa_check(p_currency text, p_amount numeric)
 returns jsonb
 language plpgsql
 stable
 set search_path = ''
as $$
declare v_bal numeric;
begin
  if p_currency is null or p_currency not in ('USD','UZS') then
    return jsonb_build_object('ok', false, 'error', 'Valyuta faqat USD yoki UZS');
  end if;
  select balance into v_bal from public.firma_kassa_balance where currency = p_currency;
  v_bal := coalesce(v_bal, 0);
  return jsonb_build_object('ok', coalesce(p_amount, 0) > 0 and v_bal >= round(p_amount, 2), 'balance', v_bal,
                            'shortfall', greatest(round(coalesce(p_amount, 0), 2) - v_bal, 0));
end;
$$;

revoke all on function public._fk_cash_move(text, text, numeric, text, text, text, text, text, text, text, text, bigint, text, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_advance_outstanding(text, text, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_give_advance(text, numeric, text, text, text, text, bigint, text, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_repay_advance(text, numeric, text, text, text, text, bigint, text, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_get_balance() from public, anon, authenticated;
revoke all on function public.kirim_firma_kassa_check(text, numeric) from public, anon, authenticated;
grant execute on function public._fk_cash_move(text, text, numeric, text, text, text, text, text, text, text, text, bigint, text, text) to service_role;
grant execute on function public.firma_kassa_advance_outstanding(text, text, text) to service_role;
grant execute on function public.firma_kassa_give_advance(text, numeric, text, text, text, text, bigint, text, text) to service_role;
grant execute on function public.firma_kassa_repay_advance(text, numeric, text, text, text, text, bigint, text, text) to service_role;
grant execute on function public.firma_kassa_get_balance() to service_role;
grant execute on function public.kirim_firma_kassa_check(text, numeric) to service_role;

-- ── 2. DILLER SAVDOSI: narx va ball serverda, qoldiq qulflab ──────────
CREATE OR REPLACE FUNCTION public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric DEFAULT 0, p_optim_price numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dealer_id bigint;
  v_filial text;
  v_stock numeric;
  v_avg numeric;
  v_optim numeric;
  v_pct numeric;
  v_settings jsonb;
  v_usd_val numeric;
  v_step numeric;
  v_points numeric := 0;
begin
  -- p_points va p_optim_price — orqaga moslik uchun qabul qilinadi, lekin ISHLATILMAYDI:
  -- diller o'z qarzi va ballarini o'zi belgilay olmasligi kerak (v10 audit J3).
  select id, filial into v_dealer_id, v_filial from dealers where auth_user_id = auth.uid();
  if v_dealer_id is null then
    raise exception 'Diller topilmadi, avval tizimga kiring';
  end if;
  if p_qty is null or p_qty = 'NaN'::numeric or p_qty <= 0 or p_qty > 1000000 then
    raise exception 'Miqdor 0 dan katta bolishi kerak';
  end if;
  if p_sell_usd is null or p_sell_usd = 'NaN'::numeric or p_sell_usd < 0 or p_sell_usd > 1000000000 then
    raise exception 'Narx notogri';
  end if;

  select qty, avg_cost_usd into v_stock, v_avg from dealer_stock where dealer_id = v_dealer_id and pid = p_pid for update;
  if v_stock is null or v_stock < p_qty then
    raise exception 'Omborda yetarli mahsulot yoq (bor: %, soralgan: %)', coalesce(v_stock,0), p_qty;
  end if;

  select nullif(optim_price, 0), coalesce(point_pct, 0) into v_optim, v_pct
    from catalog_products where id = p_pid and filial = coalesce(v_filial, 'baza');
  v_optim := coalesce(v_optim, nullif(v_avg, 0), p_sell_usd);
  v_pct := coalesce(v_pct, 0);

  if v_pct > 0 then
    select data->'settings' into v_settings from app_data where id = 'main';
    v_usd_val := coalesce((v_settings->>'pointUsdValue')::numeric, 2);
    v_step := coalesce(nullif((v_settings->>'pointRoundStep')::numeric, 0), 1);
    if v_usd_val > 0 then
      v_points := round(((p_qty * p_sell_usd * v_pct / 100) / v_usd_val) / v_step) * v_step;
    end if;
  end if;

  update dealer_stock set qty = qty - p_qty, updated_at = now()
    where dealer_id = v_dealer_id and pid = p_pid;

  insert into dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
    values (v_dealer_id, p_pid, left(p_sku, 80), left(p_name, 300), p_qty, p_sell_usd, p_qty*p_sell_usd, current_date);

  update dealers set
    total_sold_usd = total_sold_usd + (p_qty*p_sell_usd),
    debt_usd        = debt_usd + (p_qty*v_optim),
    points          = points + v_points
  where id = v_dealer_id;
end;
$function$
;

-- Eski variantlar (optim narxsiz — diller narxni 0 qilib qarzdan qochishi mumkin edi):
-- o'chirilmaydi (loyiha qoidasi), faqat dillerlar uchun yopiladi.
-- (37-migratsiya bu ikki eski nusxani o'chiradi — 23 qayta ishga tushirilsa ham xato bermasin)
do $$ begin
  if to_regprocedure('public.record_dealer_sale(bigint,numeric,numeric,text,text)') is not null then
    revoke execute on function public.record_dealer_sale(bigint, numeric, numeric, text, text) from public, anon, authenticated;
  end if;
  if to_regprocedure('public.record_dealer_sale(bigint,numeric,numeric,text,text,numeric)') is not null then
    revoke execute on function public.record_dealer_sale(bigint, numeric, numeric, text, text, numeric) from public, anon, authenticated;
  end if;
end $$;

-- ── 3. HAMKOR FUNKSIYALARI: faqat server ──────────────────────────────
revoke execute on function public.partner_archive_atomic(bigint) from public, anon, authenticated;
revoke execute on function public.partner_ledger_add_atomic(bigint, text, numeric, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.partner_monthly_calc_atomic(text, date, date, numeric, numeric) from public, anon, authenticated;
revoke execute on function public.partner_undo_period_atomic(text, boolean) from public, anon, authenticated;
revoke execute on function public.partner_upsert_atomic(bigint, text, boolean, numeric, text, text, numeric, text, numeric) from public, anon, authenticated;
grant execute on function public.partner_archive_atomic(bigint) to service_role;
grant execute on function public.partner_ledger_add_atomic(bigint, text, numeric, text, text, text, text) to service_role;
grant execute on function public.partner_monthly_calc_atomic(text, date, date, numeric, numeric) to service_role;
grant execute on function public.partner_undo_period_atomic(text, boolean) to service_role;
grant execute on function public.partner_upsert_atomic(bigint, text, boolean, numeric, text, text, numeric, text, numeric) to service_role;

-- ── 4. RUXSATLAR ──────────────────────────────────────────────────────
insert into public.permissions (key, module, label) values
  ('firma_kassa.view', 'firma_kassa', 'Firma kassasini korish'),
  ('firma_kassa.transact', 'firma_kassa', 'Firma kassasida pul harakati (kirim/chiqim, avans, filial bilan)')
on conflict (key) do nothing;
insert into public.role_permissions (role_id, permission_id)
  select r.id, p.id from public.roles r join public.permissions p on p.key in ('firma_kassa.view', 'firma_kassa.transact')
  where r.key in ('owner', 'administrator')
on conflict do nothing;
insert into public.role_permissions (role_id, permission_id)
  select r.id, p.id from public.roles r join public.permissions p on p.key = 'firma_kassa.view'
  where r.key = 'accountant'
on conflict do nothing;

-- ────────────────────────────────────────────────────────────────────
-- 8. v11 (24-migratsiya): FILIAL KASSALARI — server haqiqiy manba (F4), filial → Firma kassa atomik (B7)
-- (supabase-migration-24-v11-cash-authority.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- Migratsiya 24 (v11, 2026-10-02) — FILIAL KASSALARI: SERVER HAQIQIY MANBA
-- (F4) + FILIAL → FIRMA KASSA to'lovi atomik (B7).
-- 23-migratsiyadan KEYIN qo'llanadi (firma_kassa_* jadvallari kerak).
-- Takroriy ishga tushirish xavfsiz. Mavjud ma'lumot o'chirilmaydi.
--
-- MUAMMO (v10 auditi, F4): filial kassalarining qoldig'i (app_data JSON ichidagi
-- cashboxes[].bal) BRAUZERDA hisoblanib, serverga tayyor son sifatida yuborilardi.
-- Huquqi bor xodim (yoki brauzer konsoli) istalgan qoldiqni yozib qo'yishi mumkin edi.
--
-- YECHIM (Firma Kassa bilan bir xil yondashuv):
--  1) cashbox_balances — HAQIQIY qoldiq (filial, kassa) bo'yicha, valyutasi bilan.
--  2) cashbox_ledger — o'zgarmas jurnal: har bir pul harakati bitta yozuv,
--     balance_after bilan; (filial, op_key) UNIQUE — takroriy so'rov ikki marta yozilmaydi.
--  3) _cb_move() — yagona yozish yo'li: qator FOR UPDATE bilan qulflanadi, chiqim
--     qoldiqdan oshmaydi, valyuta mos kelishi shart.
--  4) cashbox_balances'ga ledger'siz yozish TRIGGER bilan taqiqlanadi (eski
--     funksiyalar yoki xato kod qoldiqni "jimgina" o'zgartira olmaydi).
--  5) cashbox_apply_ops() — bir amaldagi bir nechta harakat (masalan ko'chirish,
--     valyuta almashtirish) BITTA tranzaksiyada: hammasi yoki hech biri.
--  6) branch_firma_transfer() — filial kassasi ↔ Firma kassa VA filialning bazaga
--     qarzini kamaytirish BITTA tranzaksiyada (B7: yarim muvaffaqiyat yo'q).
--  7) sale_checkout_atomic_v2 — kassaga tushum ham ledger orqali; kassaga savdo
--     summasidan ortiq pul yozilmaydi.
--  8) Boshlang'ich qoldiqlar hozirgi JSON'dan BIR MARTA ko'chiriladi ('opening').
--
-- Kirish: faqat server (service_role). Brauzer (anon/authenticated) — yo'q.
-- ════════════════════════════════════════════════════════════════════

-- ── 1. cashbox_balances: valyuta ustuni ────────────────────────────────
alter table public.cashbox_balances add column if not exists currency text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'cashbox_balances_currency_chk' and conrelid = 'public.cashbox_balances'::regclass) then
    alter table public.cashbox_balances add constraint cashbox_balances_currency_chk check (currency is null or currency in ('USD','UZS'));
  end if;
end $$;

-- ── 2. cashbox_ledger — o'zgarmas jurnal ───────────────────────────────
create table if not exists public.cashbox_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  box_local_id integer not null,
  box_name text,
  currency text not null,
  direction text not null,
  amount numeric(20,2) not null,
  balance_after numeric(20,2) not null,
  op_kind text not null,
  op_key text not null,
  group_key text,
  ref_type text,
  ref_id text,
  note text,
  staff_id bigint,
  staff_name text,
  constraint cashbox_ledger_op_key_key unique (filial, op_key),
  constraint cashbox_ledger_currency_chk check (currency in ('USD','UZS')),
  constraint cashbox_ledger_direction_chk check (direction in ('in','out')),
  constraint cashbox_ledger_amount_chk check (amount > 0 or (op_kind = 'opening' and amount >= 0)),
  constraint cashbox_ledger_kind_chk check (op_kind in (
    'opening','sale','sale_fix','manual_in','manual_out','move','exchange','expense','expense_fix','salary',
    'cust_debt_pay','supp_pay','kirim_pay','dealer_pay','home_withdrawal','branch_to_firma','firma_to_branch','reset_zero')),
  constraint cashbox_ledger_text_len check (coalesce(length(note),0) <= 500 and coalesce(length(box_name),0) <= 200
    and coalesce(length(staff_name),0) <= 200 and length(op_key) <= 140 and coalesce(length(ref_id),0) <= 100)
);
create index if not exists idx_cb_ledger_box on public.cashbox_ledger (filial, box_local_id, id desc);
create index if not exists idx_cb_ledger_created on public.cashbox_ledger (filial, created_at desc);
create index if not exists idx_cb_ledger_group on public.cashbox_ledger (filial, group_key) where group_key is not null;

alter table public.cashbox_ledger enable row level security;
revoke all on public.cashbox_ledger from anon, authenticated;
grant select, insert on public.cashbox_ledger to service_role;
grant usage on sequence public.cashbox_ledger_id_seq to service_role;

-- ── 3. Qoldiqni faqat ledger orqali o'zgartirish (trigger) ─────────────
create or replace function public._cb_balances_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if coalesce(current_setting('fw.cb_move', true), '') = '1' then
    return coalesce(new, old);
  end if;
  if tg_op = 'INSERT' and coalesce(new.balance, 0) = 0 then
    return new;                                   -- bo'sh (0) qator — xavfsiz
  end if;
  if tg_op = 'UPDATE' and new.balance is not distinct from old.balance
     and (old.currency is null or new.currency is not distinct from old.currency) then
    return new;                                   -- qoldiq o'zgarmagan
  end if;
  raise exception 'CASHBOX: kassa qoldig''i faqat kassa jurnali (cashbox_ledger) orqali o''zgaradi' using errcode = 'P0001';
end;
$$;
create or replace trigger cashbox_balances_guard
  before insert or update or delete on public.cashbox_balances
  for each row execute function public._cb_balances_guard();

-- ── 4. _cb_move — yagona yozish yo'li ──────────────────────────────────
create or replace function public._cb_move(
  p_filial text, p_box integer, p_currency text, p_direction text, p_amount numeric, p_kind text, p_op_key text,
  p_group_key text default null, p_box_name text default null, p_ref_type text default null, p_ref_id text default null,
  p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns public.cashbox_ledger
 language plpgsql
 set search_path = ''
as $$
declare
  v_amt numeric;
  v_bal numeric;
  v_cur text;
  v_row public.cashbox_ledger;
begin
  if coalesce(p_filial, '') = '' or p_box is null or coalesce(p_op_key, '') = '' then
    raise exception 'CASHBOX: filial, kassa va amal kaliti majburiy' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 1000000000000 then
    raise exception 'CASHBOX: summa musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  v_amt := round(p_amount, 2);
  if v_amt <= 0 then
    raise exception 'CASHBOX: summa juda kichik' using errcode = 'P0001';
  end if;

  -- Idempotency: shu kalit bilan amal allaqachon yozilgan bo'lsa — o'sha natija.
  -- Kalit boshqa mazmun bilan qayta ishlatilsa — rad etiladi (kalitni "o'g'irlab" bo'lmaydi).
  select * into v_row from public.cashbox_ledger where filial = p_filial and op_key = p_op_key;
  if found then
    if v_row.box_local_id <> p_box or v_row.direction <> p_direction or v_row.amount <> v_amt then
      raise exception 'CASHBOX: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    return v_row;
  end if;

  if p_currency is null or p_currency not in ('USD','UZS') then
    raise exception 'CASHBOX: valyuta faqat USD yoki UZS bo''lishi mumkin' using errcode = 'P0001';
  end if;
  if p_direction is null or p_direction not in ('in','out') then
    raise exception 'CASHBOX: yo''nalish noto''g''ri' using errcode = 'P0001';
  end if;

  select balance, currency into v_bal, v_cur from public.cashbox_balances
    where filial = p_filial and box_local_id = p_box for update;
  if not found then
    insert into public.cashbox_balances (filial, box_local_id, balance, currency) values (p_filial, p_box, 0, p_currency)
      on conflict (filial, box_local_id) do nothing;
    select balance, currency into v_bal, v_cur from public.cashbox_balances
      where filial = p_filial and box_local_id = p_box for update;
  end if;
  if v_cur is not null and v_cur <> p_currency then
    raise exception 'CASHBOX: kassa valyutasi % (so''rovda %)', v_cur, p_currency using errcode = 'P0001';
  end if;
  v_bal := coalesce(v_bal, 0);

  if p_direction = 'out' then
    if v_bal < v_amt then
      raise exception 'CASHBOX: kassada mablag'' yetarli emas (qoldiq %, so''ralgan %)', v_bal, v_amt using errcode = 'P0001';
    end if;
    v_bal := v_bal - v_amt;
  else
    v_bal := v_bal + v_amt;
  end if;

  perform set_config('fw.cb_move', '1', true);
  update public.cashbox_balances set balance = v_bal, currency = p_currency, updated_at = now()
    where filial = p_filial and box_local_id = p_box;
  perform set_config('fw.cb_move', '', true);

  insert into public.cashbox_ledger
    (filial, box_local_id, box_name, currency, direction, amount, balance_after, op_kind, op_key, group_key,
     ref_type, ref_id, note, staff_id, staff_name)
  values
    (p_filial, p_box, left(p_box_name, 200), p_currency, p_direction, v_amt, v_bal, p_kind, p_op_key, p_group_key,
     left(p_ref_type, 40), left(p_ref_id, 100), left(p_note, 500), p_staff_id, left(p_staff_name, 200))
  returning * into v_row;
  return v_row;
exception when unique_violation then
  perform set_config('fw.cb_move', '', true);
  select * into v_row from public.cashbox_ledger where filial = p_filial and op_key = p_op_key;
  if found then return v_row; end if;
  raise;
end;
$$;

-- Bir filialning berilgan kassalari bo'yicha qoldiqlar xaritasi {"1": 100.00, ...}
create or replace function public._cb_balances_map(p_filial text, p_boxes integer[] default null)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select coalesce(jsonb_object_agg(box_local_id::text, balance), '{}'::jsonb)
  from public.cashbox_balances
  where filial = p_filial and (p_boxes is null or box_local_id = any(p_boxes));
$$;

-- ── 5. cashbox_apply_ops — bir amal = bitta tranzaksiya ────────────────
-- p_ops: [{"box":1,"currency":"UZS","dir":"out","amount":100,"box_name":"Naqd","note":"..","ref_type":"..","ref_id":".."}, ...]
create or replace function public.cashbox_apply_ops(
  p_filial text, p_group_key text, p_kind text, p_ops jsonb, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_n int;
  v_op jsonb;
  v_idx int;
  v_boxes integer[];
  v_row public.cashbox_ledger;
  v_entries jsonb := '[]'::jsonb;
  v_existing int;
  v_pass text;
begin
  if coalesce(p_filial, '') = '' or coalesce(p_group_key, '') = '' or length(p_group_key) > 100 then
    raise exception 'CASHBOX: filial va amal kaliti majburiy' using errcode = 'P0001';
  end if;
  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then
    raise exception 'CASHBOX: amallar ro''yxati noto''g''ri' using errcode = 'P0001';
  end if;
  v_n := jsonb_array_length(p_ops);
  if v_n < 1 or v_n > 20 then
    raise exception 'CASHBOX: bir so''rovda 1–20 ta harakat bo''lishi mumkin' using errcode = 'P0001';
  end if;

  if exists (select 1 from jsonb_array_elements(p_ops) e
             where jsonb_typeof(e) <> 'object' or coalesce(e->>'dir', '') not in ('in','out')
                or coalesce(e->>'box', '') !~ '^[0-9]{1,9}$') then
    raise exception 'CASHBOX: harakat maydonlari noto''g''ri (kassa/yo''nalish)' using errcode = 'P0001';
  end if;

  -- Bir xil kalit bilan parallel so'rovlar navbatga qo'yiladi
  perform pg_advisory_xact_lock(hashtext('cb_grp:' || p_filial || ':' || p_group_key));

  select array_agg(distinct (e->>'box')::int order by (e->>'box')::int) into v_boxes from jsonb_array_elements(p_ops) e;
  select count(*) into v_existing from public.cashbox_ledger where filial = p_filial and group_key = p_group_key;
  if v_existing > 0 then
    -- Takroriy so'rov: mazmuni AYNAN bir xil bo'lishi shart (kalitni boshqa amal uchun ishlatib bo'lmaydi)
    v_idx := 0;
    for v_op in select * from jsonb_array_elements(p_ops) loop
      v_idx := v_idx + 1;
      select * into v_row from public.cashbox_ledger where filial = p_filial and op_key = p_group_key || ':' || v_idx;
      if not found or v_row.box_local_id <> (v_op->>'box')::int or v_row.direction <> (v_op->>'dir')
         or v_row.amount <> round((v_op->>'amount')::numeric, 2) then
        raise exception 'CASHBOX: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
      end if;
    end loop;
    if v_existing <> v_n then
      raise exception 'CASHBOX: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('id', id, 'box', box_local_id, 'dir', direction, 'amount', amount,
             'balanceAfter', balance_after) order by id), '[]'::jsonb) into v_entries
      from public.cashbox_ledger where filial = p_filial and group_key = p_group_key;
    return jsonb_build_object('ok', true, 'replay', true, 'balances', public._cb_balances_map(p_filial, v_boxes), 'entries', v_entries);
  end if;

  -- Kassa qatorlari tartib bilan qulflanadi (deadlock bo'lmasligi uchun)
  perform 1 from public.cashbox_balances where filial = p_filial and box_local_id = any(v_boxes)
    order by box_local_id for update;

  -- Avval kirimlar, keyin chiqimlar (bir kassada tuzatish amali oraliqda manfiyga tushmasin)
  foreach v_pass in array array['in','out'] loop
    v_idx := 0;
    for v_op in select * from jsonb_array_elements(p_ops) loop
      v_idx := v_idx + 1;
      continue when v_op->>'dir' <> v_pass;
      v_row := public._cb_move(p_filial, (v_op->>'box')::int, v_op->>'currency', v_op->>'dir',
        (v_op->>'amount')::numeric, p_kind, p_group_key || ':' || v_idx, p_group_key, v_op->>'box_name',
        v_op->>'ref_type', v_op->>'ref_id', v_op->>'note', p_staff_id, p_staff_name);
      v_entries := v_entries || jsonb_build_object('id', v_row.id, 'box', v_row.box_local_id, 'dir', v_row.direction,
        'amount', v_row.amount, 'balanceAfter', v_row.balance_after);
    end loop;
  end loop;

  return jsonb_build_object('ok', true, 'replay', false, 'balances', public._cb_balances_map(p_filial, v_boxes), 'entries', v_entries);
end;
$$;

-- ── 6. branch_firma_transfer — filial kassasi ↔ Firma kassa (+ filial qarzi) ──
-- p_direction: 'to_firma' (filialdan Firma kassaga) | 'from_firma' (Firma kassadan filialga)
-- p_reduce_debt: true — to'lov filialning bazaga qarzini (app_data.branchDebt, USD) kamaytiradi.
-- UZS kassadan to'langanda qarz SERVERDAGI kurs (settings.usdUzs) bo'yicha USD'ga o'giriladi.
create or replace function public.branch_firma_transfer(
  p_filial text, p_box integer, p_currency text, p_direction text, p_amount numeric, p_key text,
  p_reduce_debt boolean default false, p_box_name text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_key text;
  v_cb public.cashbox_ledger;
  v_fk public.firma_kassa_ledger;
  v_amt numeric;
  v_rate numeric;
  v_usd numeric := null;
  v_data jsonb;
  v_debt_before numeric := null;
  v_debt_after numeric := null;
  v_note text;
begin
  if coalesce(p_key, '') = '' or length(p_key) > 100 then
    raise exception 'CASHBOX: amal kaliti majburiy' using errcode = 'P0001';
  end if;
  if p_direction is null or p_direction not in ('to_firma','from_firma') then
    raise exception 'CASHBOX: yo''nalish noto''g''ri' using errcode = 'P0001';
  end if;
  if coalesce(p_reduce_debt, false) and p_direction <> 'to_firma' then
    raise exception 'CASHBOX: qarz faqat filialdan to''lov bilan kamayadi' using errcode = 'P0001';
  end if;
  if coalesce(p_filial, '') = '' or (p_filial = 'baza' and coalesce(p_reduce_debt, false)) then
    raise exception 'CASHBOX: bu amal faqat filial uchun' using errcode = 'P0001';
  end if;
  v_key := 'bft:' || p_key;
  perform pg_advisory_xact_lock(hashtext('cb_bft:' || p_filial || ':' || v_key));

  -- Takroriy so'rov: ikkala tomon ham yozilgan — birinchi natija qaytadi (qarz ikkinchi marta kamaymaydi)
  select * into v_cb from public.cashbox_ledger where filial = p_filial and op_key = v_key;
  if found then
    select * into v_fk from public.firma_kassa_ledger where idem_key = v_key;
    if v_cb.box_local_id <> p_box or v_cb.amount <> round(p_amount, 2)
       or v_cb.op_kind <> (case when p_direction = 'to_firma' then 'branch_to_firma' else 'firma_to_branch' end) then
      raise exception 'CASHBOX: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    select data into v_data from public.app_data where id = 'main';
    return jsonb_build_object('ok', true, 'replay', true, 'filial', p_filial, 'box', v_cb.box_local_id, 'currency', v_cb.currency,
      'amount', v_cb.amount, 'branchBalance', (select balance from public.cashbox_balances where filial = p_filial and box_local_id = p_box),
      'firmaBalance', (select balance from public.firma_kassa_balance where currency = v_cb.currency),
      'debtAfter', (v_data->'branchDebt'->>p_filial)::numeric, 'branchEntryId', v_cb.id, 'firmaEntryId', v_fk.id);
  end if;

  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 1000000000000 then
    raise exception 'CASHBOX: summa musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  v_amt := round(p_amount, 2);

  -- Qulflash tartibi DOIM bir xil (deadlock bo'lmasligi uchun): filial qarzi → filial kassasi → Firma kassa
  if coalesce(p_reduce_debt, false) then
    perform 1 from public.app_data where id = 'main' for update;
  end if;
  perform 1 from public.cashbox_balances where filial = p_filial and box_local_id = p_box for update;
  perform 1 from public.firma_kassa_balance where currency = p_currency for update;

  if coalesce(p_reduce_debt, false) then
    select data into v_data from public.app_data where id = 'main' for update;
    if v_data is null then
      raise exception 'CASHBOX: asosiy ma''lumot topilmadi' using errcode = 'P0001';
    end if;
    v_debt_before := round(coalesce(nullif(v_data->'branchDebt'->>p_filial, '')::numeric, 0), 2);
    if p_currency = 'USD' then
      v_usd := v_amt;
    else
      v_rate := nullif(nullif(v_data->'settings'->>'usdUzs', '')::numeric, 0);
      if v_rate is null or v_rate <= 0 then
        raise exception 'CASHBOX: USD/UZS kursi sozlanmagan' using errcode = 'P0001';
      end if;
      v_usd := round(v_amt / v_rate, 2);
    end if;
    if v_debt_before <= 0 then
      raise exception 'CASHBOX: filialning bazaga qarzi yo''q' using errcode = 'P0001';
    end if;
    if v_usd > v_debt_before + 0.01 then
      raise exception 'CASHBOX: to''lov (% $) qarzdan (% $) oshib ketdi', v_usd, v_debt_before using errcode = 'P0001';
    end if;
    v_debt_after := greatest(round(v_debt_before - v_usd, 2), 0);
    v_note := left(coalesce(p_note || ' · ', '') || 'Filial qarzi: ' || v_debt_before || ' → ' || v_debt_after || ' $'
              || case when v_rate is not null then ' (kurs ' || v_rate || ')' else '' end, 500);
  else
    v_note := p_note;
  end if;

  if p_direction = 'to_firma' then
    v_cb := public._cb_move(p_filial, p_box, p_currency, 'out', v_amt, 'branch_to_firma', v_key, v_key, p_box_name,
                            case when p_reduce_debt then 'branch_debt' else 'firma_kassa' end, p_filial, v_note, p_staff_id, p_staff_name);
    v_fk := public._fk_cash_move(p_currency, 'in', v_amt, 'branch_in', 'branch', p_filial, p_filial, p_filial,
                                 case when p_reduce_debt then 'branch_debt' else 'cashbox' end, p_box::text, v_note, p_staff_id, p_staff_name, v_key);
  else
    v_fk := public._fk_cash_move(p_currency, 'out', v_amt, 'branch_out', 'branch', p_filial, p_filial, p_filial,
                                 'cashbox', p_box::text, v_note, p_staff_id, p_staff_name, v_key);
    v_cb := public._cb_move(p_filial, p_box, p_currency, 'in', v_amt, 'firma_to_branch', v_key, v_key, p_box_name,
                            'firma_kassa', p_filial, v_note, p_staff_id, p_staff_name);
  end if;

  if coalesce(p_reduce_debt, false) then
    update public.app_data
       set data = jsonb_set(data, '{branchDebt}', coalesce(data->'branchDebt', '{}'::jsonb) || jsonb_build_object(p_filial, v_debt_after)),
           updated_at = now()
     where id = 'main';
  end if;

  return jsonb_build_object('ok', true, 'replay', false, 'filial', p_filial, 'box', p_box, 'currency', p_currency, 'amount', v_amt,
    'amountUsd', v_usd, 'rate', v_rate, 'debtBefore', v_debt_before, 'debtAfter', v_debt_after,
    'branchBalance', v_cb.balance_after, 'firmaBalance', v_fk.balance_after, 'branchEntryId', v_cb.id, 'firmaEntryId', v_fk.id);
end;
$$;

-- ── 7. Savdo: kassaga tushum ledger orqali ─────────────────────────────
CREATE OR REPLACE FUNCTION public.sale_checkout_atomic_v2(p_filial text, p_items jsonb, p_disc_pct numeric, p_paid_usd numeric, p_cust_id bigint, p_box_payments jsonb, p_inv text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_item jsonb;
  v_bp jsonb;
  v_pid bigint;
  v_qty numeric;
  v_remaining numeric;
  v_batch record;
  v_take numeric;
  v_subtotal numeric := 0;
  v_total numeric;
  v_cost numeric := 0;
  v_profit numeric;
  v_debt numeric;
  v_change numeric;
  v_sale_id bigint;
  v_box int;
  v_amt numeric;
  v_cur text;
  v_rate numeric;
  v_box_usd numeric := 0;
  v_idx int := 0;
  v_boxes integer[] := '{}';
begin
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_subtotal := v_subtotal + (v_item->>'qty')::numeric * (v_item->>'sell_usd')::numeric;
  end loop;
  v_total := v_subtotal * (1 - coalesce(p_disc_pct,0)/100);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'pid')::bigint;
    v_qty := (v_item->>'qty')::numeric;

    if coalesce((v_item->>'direct_supply')::boolean, false) then
      v_cost := v_cost + v_qty * (v_item->>'cost_usd')::numeric;
      if v_item->>'supp_id' is not null then
        insert into public.supplier_balances (filial, supplier_local_id, debt)
          values (p_filial, (v_item->>'supp_id')::bigint, v_qty * (v_item->>'cost_usd')::numeric)
          on conflict (filial, supplier_local_id) do update
            set debt = public.supplier_balances.debt + excluded.debt, updated_at = now();
      end if;
    else
      v_remaining := v_qty;
      for v_batch in
        select id, qty, sold, cost_usd from public.batches
        where filial = p_filial and pid = v_pid and status = 'active' and qty > sold
        order by batch_date asc nulls last, id asc
        for update
      loop
        exit when v_remaining <= 0;
        v_take := least(v_batch.qty - v_batch.sold, v_remaining);
        update public.batches set sold = sold + v_take,
               status = case when qty <= sold + v_take then 'empty' else status end,
               updated_at = now()
          where id = v_batch.id;
        v_cost := v_cost + v_take * v_batch.cost_usd;
        v_remaining := v_remaining - v_take;
      end loop;
      if v_remaining > 0 then
        raise exception 'Omborda yetarli qoldiq yo''q: pid=%, yetishmayotgan miqdor=%', v_pid, v_remaining;
      end if;
    end if;
  end loop;

  v_profit := v_total - v_cost;
  v_debt := greatest(0, v_total - p_paid_usd);
  v_change := greatest(0, p_paid_usd - v_total);

  insert into public.sales (filial, inv, cust_id, subtotal_usd, disc_pct, total_usd, cost_usd, profit_usd, paid_usd, debt_usd, items)
    values (p_filial, p_inv, p_cust_id, v_subtotal, coalesce(p_disc_pct,0), v_total, v_cost, v_profit, least(p_paid_usd, v_total), v_debt, p_items)
    returning id into v_sale_id;

  if p_cust_id is not null and v_debt > 0 then
    insert into public.customer_balances (filial, customer_local_id, debt)
      values (p_filial, p_cust_id, v_debt)
      on conflict (filial, customer_local_id) do update
        set debt = public.customer_balances.debt + excluded.debt, updated_at = now();
  end if;

  -- MIXED-PAYMENT: har bir kassaga tushum — shu tranzaksiya ichida, kassa jurnali orqali (v11).
  -- Kassaga jami tushum savdo summasidan (yaxlitlash uchun 2% / 1$ chegarasi bilan) oshmaydi.
  if p_box_payments is not null and jsonb_typeof(p_box_payments) = 'array' then
    for v_bp in select * from jsonb_array_elements(p_box_payments) loop
      v_idx := v_idx + 1;
      v_box := (v_bp->>'box_id')::int;
      v_amt := (v_bp->>'amount_native')::numeric;
      continue when v_amt is null or v_amt <= 0;
      select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = v_box;
      v_cur := coalesce(v_cur, v_bp->>'currency');
      if v_cur is null then
        raise exception 'CASHBOX: kassa valyutasi noma''lum (kassa %)', v_box using errcode = 'P0001';
      end if;
      if v_cur = 'USD' then
        v_box_usd := v_box_usd + v_amt;
      else
        if v_rate is null then
          select nullif(nullif(data->'settings'->>'usdUzs', '')::numeric, 0) into v_rate from public.app_data where id = 'main';
          if v_rate is null then
            raise exception 'CASHBOX: USD/UZS kursi sozlanmagan' using errcode = 'P0001';
          end if;
        end if;
        v_box_usd := v_box_usd + v_amt / v_rate;
      end if;
      -- Kalit savdo ID'siga bog'langan (chek raqami qurilmalar orasida takrorlanishi mumkin)
      perform public._cb_move(p_filial, v_box, v_cur, 'in', v_amt, 'sale', 'sale:' || v_sale_id || ':' || v_idx, 'sale:' || v_sale_id,
                              v_bp->>'box_name', 'sale', p_inv, 'Savdo ' || p_inv, null, null);
      v_boxes := v_boxes || v_box;
    end loop;
    if v_box_usd > v_total + greatest(1, v_total * 0.02) then
      raise exception 'CASHBOX: kassaga tushum (% $) savdo summasidan (% $) oshib ketdi — qaytimni ayiring', round(v_box_usd, 2), round(v_total, 2) using errcode = 'P0001';
    end if;
  end if;

  return jsonb_build_object(
    'ok', true, 'saleId', v_sale_id, 'inv', p_inv,
    'subtotalUsd', v_subtotal, 'totalUsd', v_total, 'costUsd', v_cost,
    'profitUsd', v_profit, 'debtUsd', v_debt, 'changeUsd', v_change,
    'balances', public._cb_balances_map(p_filial, v_boxes)
  );
end;
$function$
;

-- ── 8. Boshlang'ich qoldiqlar — hozirgi JSON'dan BIR MARTA ───────────
-- Manba: app_data_branches.data.cashboxes (ilova shu yerdan yuklaydi), yo'q bo'lsa
-- app_data.data.branchStore[filial].cashboxes. Kassada hali jurnal yozuvi bo'lmasa —
-- qoldiq JSON'dagi qiymatga tenglashtiriladi va 'opening' yozuvi qoldiriladi.
-- Qayta ishga tushirilsa: jurnalida yozuvi bor kassaga TEGILMAYDI.
do $$
declare
  r record;
  v_cur text;
  v_bal numeric;
begin
  perform set_config('fw.cb_move', '1', true);
  for r in
    with src as (
      select b.branch_key as filial, b.data->'cashboxes' as boxes from public.app_data_branches b
       where jsonb_typeof(b.data->'cashboxes') = 'array'
      union all
      select s.key, s.value->'cashboxes' from public.app_data a, jsonb_each(coalesce(a.data->'branchStore', '{}'::jsonb)) s
       where a.id = 'main' and jsonb_typeof(s.value->'cashboxes') = 'array'
         and not exists (select 1 from public.app_data_branches b2 where b2.branch_key = s.key and jsonb_typeof(b2.data->'cashboxes') = 'array')
    )
    select src.filial, (bx->>'id')::int as box, bx->>'name' as box_name, bx->>'cur' as cur,
           coalesce(nullif(bx->>'bal', '')::numeric, 0) as bal
      from src, jsonb_array_elements(src.boxes) bx
     where jsonb_typeof(bx) = 'object' and (bx->>'id') ~ '^[0-9]{1,9}$'
  loop
    continue when exists (select 1 from public.cashbox_ledger l where l.filial = r.filial and l.box_local_id = r.box);
    v_cur := case when r.cur in ('USD','UZS') then r.cur else 'UZS' end;
    v_bal := round(r.bal, 2);
    insert into public.cashbox_balances (filial, box_local_id, balance, currency, updated_at)
      values (r.filial, r.box, v_bal, v_cur, now())
      on conflict (filial, box_local_id) do update set balance = excluded.balance, currency = excluded.currency, updated_at = now();
    insert into public.cashbox_ledger (filial, box_local_id, box_name, currency, direction, amount, balance_after, op_kind, op_key, note)
      values (r.filial, r.box, left(r.box_name, 200), v_cur, case when v_bal < 0 then 'out' else 'in' end, abs(v_bal), v_bal,
              'opening', 'opening:' || r.box, 'Boshlang''ich qoldiq (24-migratsiya, ilovadagi qiymat)')
      on conflict (filial, op_key) do nothing;
  end loop;
  perform set_config('fw.cb_move', '', true);
end $$;

-- ── 9. Ruxsatlar: faqat server ─────────────────────────────────────────
revoke all on function public._cb_balances_guard() from public, anon, authenticated;
revoke all on function public._cb_move(text, integer, text, text, numeric, text, text, text, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public._cb_balances_map(text, integer[]) from public, anon, authenticated;
revoke all on function public.cashbox_apply_ops(text, text, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.branch_firma_transfer(text, integer, text, text, numeric, text, boolean, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.sale_checkout_atomic_v2(text, jsonb, numeric, numeric, bigint, jsonb, text) from public, anon, authenticated;
grant execute on function public._cb_move(text, integer, text, text, numeric, text, text, text, text, text, text, text, bigint, text) to service_role;
grant execute on function public._cb_balances_map(text, integer[]) to service_role;
grant execute on function public.cashbox_apply_ops(text, text, text, jsonb, bigint, text) to service_role;
grant execute on function public.branch_firma_transfer(text, integer, text, text, numeric, text, boolean, text, text, bigint, text) to service_role;
grant execute on function public.sale_checkout_atomic_v2(text, jsonb, numeric, numeric, bigint, jsonb, text) to service_role;

-- ────────────────────────────────────────────────────────────────────
-- 9. v23 (25-migratsiya): Firma kassa kengaytmasi, filial qarzi, to'lov+kassa atomik, xavfsizlik
-- (supabase-migration-25-v23-hardening.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- Migratsiya 25 (v23, 2026-10-02) — FIRMA KASSA kengaytmasi, FILIAL QARZI (Bazadan),
-- TO'LOV + KASSA atomik, xavfsizlik (RLS/GRANT) mustahkamlash.
-- 23 va 24-migratsiyalardan KEYIN qo'llanadi. Takroriy ishga tushirish xavfsiz.
-- Ma'lumot o'chirilmaydi: faqat qo'shiladi (ustun, funksiya, trigger, indeks)
-- va ortiqcha ruxsatlar olib tashlanadi.
--
-- 1) firma_kassa_ledger: source_type / source_ref / reversal_of / reversed_by —
--    har bir yozuv manbasi aniq; bekor qilish faqat TESKARI yozuv bilan (o'chirish
--    va tahrirlash trigger bilan taqiqlanadi). Yangi amallar: 'opening' (boshlang'ich
--    qoldiq), 'reversal_in/out'.
-- 2) firma_kassa_reverse() — yozuvni teskari yozuv bilan bekor qilish (idempotent).
-- 3) branch_firma_loan() — filial Bazadan (Firma kassadan) qarz oladi / qaytaradi:
--    Firma kassa + filial kassasi + qarz qoldig'i BITTA tranzaksiyada.
-- 4) firma_kassa_branch_summary() — har bir filialning Bazaga qarzlari (tovar va pul).
-- 5) cash_payment_atomic() — mijoz/ta'minotchi/diller to'lovi va kunlik "uyga berish":
--    kassa harakati + to'lov yozuvi (+ diller qarzi) BITTA tranzaksiyada.
-- 6) cashbox_ledger: filial qarzi turlari; jurnal o'zgarmas (trigger).
-- 7) Xavfsizlik: brauzer ishlatmaydigan jadval/funksiyalardan anon/authenticated
--    ruxsatlari olinadi (hozir RLS to'sib turibdi — bu ikkinchi himoya qatlami).
-- 8) Hamkorlar SQL jadvallari — ilova ishlatmaydi (haqiqiy manba: app_data.partners);
--    izoh bilan belgilanadi, o'chirilmaydi.
-- ════════════════════════════════════════════════════════════════════

-- ── 1. firma_kassa_ledger: manba va bekor qilish ma'lumoti ─────────────
alter table public.firma_kassa_ledger add column if not exists source_type text;
alter table public.firma_kassa_ledger add column if not exists source_ref text;
alter table public.firma_kassa_ledger add column if not exists reversal_of bigint;
alter table public.firma_kassa_ledger add column if not exists reversed_by bigint;
alter table public.firma_kassa_ledger add column if not exists reversed_at timestamp with time zone;

-- Amal turlari: + boshlang'ich qoldiq, + teskari yozuv
alter table public.firma_kassa_ledger drop constraint if exists firma_kassa_ledger_op_chk;
alter table public.firma_kassa_ledger add constraint firma_kassa_ledger_op_chk check (
  (direction = 'in'  and op_type in ('deposit','branch_in','advance_repay','adjust_in','opening','reversal_in')) or
  (direction = 'out' and op_type in ('withdraw','branch_out','advance_give','kirim_payment','partner_withdrawal','adjust_out','reversal_out'))
);

create or replace function public._fk_source_type(p_op_type text, p_cp_type text, p_ref_type text)
 returns text
 language sql
 immutable
 set search_path = ''
as $$
  select case
    when p_op_type = 'opening' then 'opening_balance'
    when p_op_type in ('adjust_in','adjust_out') then 'manual_adjustment'
    when p_op_type = 'deposit' then 'deposit'
    when p_op_type = 'withdraw' then 'withdraw'
    when p_op_type = 'branch_in' and p_ref_type = 'branch_debt' then 'branch_debt_payment'
    when p_op_type = 'branch_in' then 'branch_transfer_in'
    when p_op_type = 'branch_out' then 'branch_transfer_out'
    when p_op_type = 'advance_give' and p_cp_type = 'branch' then 'branch_loan'
    when p_op_type = 'advance_give' then 'advance_given'
    when p_op_type = 'advance_repay' then 'advance_repayment'
    when p_op_type = 'kirim_payment' and p_ref_type = 'kirim_shortfall' then 'kirim_shortfall'
    when p_op_type = 'kirim_payment' then 'kirim_payment'
    when p_op_type = 'partner_withdrawal' then 'partner_withdrawal'
    when p_op_type in ('reversal_in','reversal_out') then 'reversal'
  end;
$$;

-- Mavjud yozuvlar (agar 23-migratsiyadan keyin ishlatilgan bo'lsa) — bir marta to'ldiriladi
update public.firma_kassa_ledger
   set source_type = public._fk_source_type(op_type, counterparty_type, ref_type),
       source_ref  = coalesce(source_ref, nullif(concat_ws(':', ref_type, ref_id), ''))
 where source_type is null;

alter table public.firma_kassa_ledger drop constraint if exists firma_kassa_ledger_source_chk;
alter table public.firma_kassa_ledger add constraint firma_kassa_ledger_source_chk check (source_type is not null and source_type in (
  'opening_balance','manual_adjustment','deposit','withdraw','branch_debt_payment','branch_transfer_in','branch_transfer_out',
  'branch_loan','advance_given','advance_repayment','kirim_payment','kirim_shortfall','partner_withdrawal','reversal'));
create index if not exists idx_fk_ledger_source on public.firma_kassa_ledger (source_type, source_ref);

-- Yangi yozuv: manba avtomatik; teskari yozuv bo'lsa — qaysi yozuvni bekor qilgani
create or replace function public._fk_ledger_defaults()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  new.source_type := coalesce(new.source_type, public._fk_source_type(new.op_type, new.counterparty_type, new.ref_type));
  new.source_ref  := coalesce(new.source_ref, nullif(concat_ws(':', new.ref_type, new.ref_id), ''));
  if new.op_type in ('reversal_in','reversal_out') and new.ref_type = 'reversal' and new.ref_id ~ '^[0-9]{1,18}$' then
    new.reversal_of := new.ref_id::bigint;
  end if;
  new.reversed_by := null; new.reversed_at := null;
  return new;
end;
$$;
create or replace trigger firma_kassa_ledger_defaults
  before insert on public.firma_kassa_ledger
  for each row execute function public._fk_ledger_defaults();

-- O'zgarmas jurnal: o'chirish yo'q; tahrirlash — faqat "bekor qilindi" belgisini bir marta qo'yish
create or replace function public._ledger_immutable()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'LEDGER: jurnal yozuvini o''chirib bo''lmaydi (teskari yozuv qiling)' using errcode = 'P0001';
  end if;
  if tg_table_name = 'firma_kassa_ledger' then
    if (to_jsonb(old)->>'reversed_by') is null and (to_jsonb(new)->>'reversed_by') is not null
       and (to_jsonb(new) - 'reversed_by' - 'reversed_at') = (to_jsonb(old) - 'reversed_by' - 'reversed_at') then
      return new;
    end if;
  end if;
  raise exception 'LEDGER: jurnal yozuvini o''zgartirib bo''lmaydi' using errcode = 'P0001';
end;
$$;
create or replace trigger firma_kassa_ledger_immutable
  before update or delete on public.firma_kassa_ledger
  for each row execute function public._ledger_immutable();
create or replace trigger cashbox_ledger_immutable
  before update or delete on public.cashbox_ledger
  for each row execute function public._ledger_immutable();

grant update (reversed_by, reversed_at) on public.firma_kassa_ledger to service_role;

-- Qolgan avans va qoldiq hisobida bekor qilingan yozuvlar hisobga olinmaydi
create or replace function public.firma_kassa_advance_outstanding(p_currency text, p_counterparty_type text, p_counterparty_id text)
 returns numeric
 language sql
 stable
 set search_path = ''
as $$
  select coalesce(sum(case when op_type = 'advance_give' then amount else -amount end), 0)
  from public.firma_kassa_ledger
  where currency = p_currency and counterparty_type = p_counterparty_type and counterparty_id = p_counterparty_id
    and op_type in ('advance_give','advance_repay') and reversed_by is null;
$$;

create or replace function public.firma_kassa_get_balance()
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object(
    'balances', coalesce((select jsonb_object_agg(currency, balance) from public.firma_kassa_balance), '{}'::jsonb),
    'advances', coalesce((
      select jsonb_agg(a order by a->>'counterparty_name') from (
        select jsonb_build_object('currency', currency, 'counterparty_type', counterparty_type, 'counterparty_id', counterparty_id,
                                  'counterparty_name', max(counterparty_name),
                                  'outstanding', sum(case when op_type = 'advance_give' then amount else -amount end)) a
        from public.firma_kassa_ledger
        where op_type in ('advance_give','advance_repay') and reversed_by is null
        group by currency, counterparty_type, counterparty_id
        having sum(case when op_type = 'advance_give' then amount else -amount end) > 0
      ) t), '[]'::jsonb)
  );
$$;

-- ── 2. Yozuvni bekor qilish (teskari yozuv) ───────────────────────────
create or replace function public.firma_kassa_reverse(
  p_entry_id bigint, p_idem_key text, p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns public.firma_kassa_ledger
 language plpgsql
 set search_path = ''
as $$
declare
  v_orig public.firma_kassa_ledger;
  v_rev public.firma_kassa_ledger;
  v_key text;
begin
  if coalesce(p_idem_key, '') = '' or length(p_idem_key) > 100 then
    raise exception 'FIRMA_KASSA: amal kaliti majburiy' using errcode = 'P0001';
  end if;
  v_key := 'rev:' || p_idem_key;
  select * into v_rev from public.firma_kassa_ledger where idem_key = v_key;
  if found then
    if v_rev.reversal_of is distinct from p_entry_id then
      raise exception 'FIRMA_KASSA: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    return v_rev;
  end if;

  select * into v_orig from public.firma_kassa_ledger where id = p_entry_id for update;
  if not found then
    raise exception 'FIRMA_KASSA: yozuv topilmadi' using errcode = 'P0001';
  end if;
  if v_orig.reversed_by is not null then
    raise exception 'FIRMA_KASSA: bu yozuv allaqachon bekor qilingan' using errcode = 'P0001';
  end if;
  if v_orig.op_type in ('reversal_in','reversal_out') then
    raise exception 'FIRMA_KASSA: teskari yozuvni bekor qilib bo''lmaydi' using errcode = 'P0001';
  end if;
  -- Filial kassasi bilan bog'langan yozuvlar (filial bilan o'tkazma, qarz to'lovi, filial qarzi)
  -- ikkala tomonda ham bekor qilinishi kerak — bu yerda emas (teskari amal bilan bajariladi)
  if v_orig.op_type in ('branch_in','branch_out') or v_orig.counterparty_type = 'branch' or coalesce(v_orig.idem_key, '') like 'bf%' then
    raise exception 'FIRMA_KASSA: filial bilan bog''liq yozuvni bu yerda bekor qilib bo''lmaydi — teskari amal (filialga qaytarish) qiling' using errcode = 'P0001';
  end if;
  if v_orig.op_type = 'advance_give'
     and public.firma_kassa_advance_outstanding(v_orig.currency, v_orig.counterparty_type, v_orig.counterparty_id) < v_orig.amount then
    raise exception 'FIRMA_KASSA: avansning bir qismi qaytarilgan — avval qaytarishlarni bekor qiling' using errcode = 'P0001';
  end if;

  v_rev := public._fk_cash_move(v_orig.currency, case when v_orig.direction = 'in' then 'out' else 'in' end, v_orig.amount,
            case when v_orig.direction = 'in' then 'reversal_out' else 'reversal_in' end,
            v_orig.counterparty_type, v_orig.counterparty_id, v_orig.counterparty_name, v_orig.filial,
            'reversal', v_orig.id::text, left(coalesce(p_note, '') || ' (bekor: #' || v_orig.id || ')', 500), p_staff_id, p_staff_name, v_key);
  update public.firma_kassa_ledger set reversed_by = v_rev.id, reversed_at = now() where id = v_orig.id;
  return v_rev;
end;
$$;

-- ── 3. Filial Bazadan (Firma kassadan) qarz oladi / qaytaradi ─────────
alter table public.cashbox_ledger drop constraint if exists cashbox_ledger_kind_chk;
alter table public.cashbox_ledger add constraint cashbox_ledger_kind_chk check (op_kind in (
  'opening','sale','sale_fix','manual_in','manual_out','move','exchange','expense','expense_fix','salary',
  'cust_debt_pay','supp_pay','kirim_pay','dealer_pay','home_withdrawal','branch_to_firma','firma_to_branch','reset_zero',
  'branch_loan_in','branch_loan_repay'));

create or replace function public.branch_firma_loan(
  p_filial text, p_box integer, p_currency text, p_direction text, p_amount numeric, p_key text,
  p_box_name text default null, p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_key text;
  v_amt numeric;
  v_out numeric;
  v_cb public.cashbox_ledger;
  v_fk public.firma_kassa_ledger;
begin
  if coalesce(p_key, '') = '' or length(p_key) > 100 then
    raise exception 'CASHBOX: amal kaliti majburiy' using errcode = 'P0001';
  end if;
  if p_direction is null or p_direction not in ('give','repay') then
    raise exception 'CASHBOX: yo''nalish noto''g''ri' using errcode = 'P0001';
  end if;
  if coalesce(p_filial, '') = '' or p_filial = 'baza' then
    raise exception 'CASHBOX: qarz faqat filialga beriladi' using errcode = 'P0001';
  end if;
  v_key := 'bfl:' || p_key;
  perform pg_advisory_xact_lock(hashtext('cb_bfl:' || p_filial || ':' || v_key));
  -- Bir filial qarzi bo'yicha parallel amallar navbatga qo'yiladi (firma_kassa_repay_advance bilan bir xil qulf)
  perform pg_advisory_xact_lock(hashtext('fk_adv:' || coalesce(p_currency, '') || ':branch:' || p_filial));

  select * into v_cb from public.cashbox_ledger where filial = p_filial and op_key = v_key;
  if found then
    if v_cb.box_local_id <> p_box or v_cb.amount <> round(p_amount, 2)
       or v_cb.op_kind <> (case when p_direction = 'give' then 'branch_loan_in' else 'branch_loan_repay' end) then
      raise exception 'CASHBOX: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    select * into v_fk from public.firma_kassa_ledger where idem_key = v_key;
    return jsonb_build_object('ok', true, 'replay', true, 'filial', p_filial, 'box', p_box, 'currency', v_cb.currency, 'amount', v_cb.amount,
      'outstanding', public.firma_kassa_advance_outstanding(v_cb.currency, 'branch', p_filial),
      'branchBalance', (select balance from public.cashbox_balances where filial = p_filial and box_local_id = p_box),
      'firmaBalance', (select balance from public.firma_kassa_balance where currency = v_cb.currency),
      'branchEntryId', v_cb.id, 'firmaEntryId', v_fk.id);
  end if;

  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 1000000000000 then
    raise exception 'CASHBOX: summa musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  v_amt := round(p_amount, 2);
  -- Qulflash tartibi: filial kassasi → Firma kassa (branch_firma_transfer bilan bir xil)
  perform 1 from public.cashbox_balances where filial = p_filial and box_local_id = p_box for update;
  perform 1 from public.firma_kassa_balance where currency = p_currency for update;

  if p_direction = 'give' then
    v_fk := public._fk_cash_move(p_currency, 'out', v_amt, 'advance_give', 'branch', p_filial, p_filial, p_filial,
                                 'branch_loan', p_box::text, p_note, p_staff_id, p_staff_name, v_key);
    v_cb := public._cb_move(p_filial, p_box, p_currency, 'in', v_amt, 'branch_loan_in', v_key, v_key, p_box_name,
                            'branch_loan', p_filial, coalesce(p_note, 'Bazadan qarz'), p_staff_id, p_staff_name);
  else
    v_out := public.firma_kassa_advance_outstanding(p_currency, 'branch', p_filial);
    if v_amt > v_out + 0.005 then
      raise exception 'CASHBOX: qaytarish (%) filialning Bazadan qarzidan (%) oshib ketdi', v_amt, v_out using errcode = 'P0001';
    end if;
    v_cb := public._cb_move(p_filial, p_box, p_currency, 'out', v_amt, 'branch_loan_repay', v_key, v_key, p_box_name,
                            'branch_loan', p_filial, coalesce(p_note, 'Bazaga qarz qaytarildi'), p_staff_id, p_staff_name);
    v_fk := public._fk_cash_move(p_currency, 'in', v_amt, 'advance_repay', 'branch', p_filial, p_filial, p_filial,
                                 'branch_loan', p_box::text, p_note, p_staff_id, p_staff_name, v_key);
  end if;

  return jsonb_build_object('ok', true, 'replay', false, 'filial', p_filial, 'box', p_box, 'currency', p_currency, 'amount', v_amt,
    'outstanding', public.firma_kassa_advance_outstanding(p_currency, 'branch', p_filial),
    'branchBalance', v_cb.balance_after, 'firmaBalance', v_fk.balance_after, 'branchEntryId', v_cb.id, 'firmaEntryId', v_fk.id);
end;
$$;

-- ── 4. Filiallarning Bazaga qarzlari (hisobot) ────────────────────────
create or replace function public.firma_kassa_branch_summary(p_filial text default null)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  with f as (
    select distinct filial from public.cashbox_balances where filial <> 'baza'
    union select key from public.app_data, jsonb_object_keys(coalesce(data->'branchDebt', '{}'::jsonb)) key where id = 'main'
    union select distinct counterparty_id from public.firma_kassa_ledger where counterparty_type = 'branch'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'filial', f.filial,
    'goodsDebtUsd', coalesce((select nullif(data->'branchDebt'->>f.filial, '')::numeric from public.app_data where id = 'main'), 0),
    'loanUsd', public.firma_kassa_advance_outstanding('USD', 'branch', f.filial),
    'loanUzs', public.firma_kassa_advance_outstanding('UZS', 'branch', f.filial),
    'cashUsd', coalesce((select sum(balance) from public.cashbox_balances b where b.filial = f.filial and b.currency = 'USD'), 0),
    'cashUzs', coalesce((select sum(balance) from public.cashbox_balances b where b.filial = f.filial and b.currency = 'UZS'), 0)
  ) order by f.filial), '[]'::jsonb)
  from f where f.filial is not null and (p_filial is null or f.filial = p_filial);
$$;

-- ── 5. To'lov + kassa harakati — bitta tranzaksiya ────────────────────
-- Mijoz/ta'minotchi ID'lari ilovada uid() (~1.7e15) — integer (max 2.1e9) ga SIG'MAYDI:
-- eski customer-debt-payment-add / supplier-payment-add har bir haqiqiy to'lovda
-- "integer out of range" bilan yiqilardi (brauzer xatoni yutib, "fail-open" davom etardi).
-- Kengaytirish (integer → bigint) — ma'lumot yo'qolmaydi; faqat hali integer bo'lsa.
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='customer_debt_payments'
             and column_name='customer_local_id' and data_type='integer') then
    alter table public.customer_debt_payments alter column customer_local_id type bigint;
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='supplier_payments'
             and column_name='supplier_local_id' and data_type='integer') then
    alter table public.supplier_payments alter column supplier_local_id type bigint;
  end if;
end $$;

alter table public.dealer_payments add column if not exists idem_key text;
create unique index if not exists dealer_payments_idem_key_uq on public.dealer_payments (idem_key) where idem_key is not null;

create or replace function public.cash_payment_atomic(
  p_filial text, p_group_key text, p_kind text, p_ops jsonb, p_record_type text, p_record jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_res jsonb;
  v_amt numeric;
  v_debt numeric;
  v_dealer record;
  v_extra jsonb := '{}'::jsonb;
begin
  if p_record_type is null or p_record_type not in ('customer_debt_payment','supplier_payment','dealer_payment','home_withdrawal') then
    raise exception 'CASHBOX: to''lov turi noto''g''ri' using errcode = 'P0001';
  end if;
  if p_record is null or jsonb_typeof(p_record) <> 'object' then
    raise exception 'CASHBOX: to''lov ma''lumoti yo''q' using errcode = 'P0001';
  end if;

  -- Diller qarzi: qulflab o'qiladi, qarzdan ortiq to'lov rad etiladi (kassa harakatidan OLDIN)
  if p_record_type = 'dealer_payment' then
    v_amt := round((p_record->>'amount_usd')::numeric, 2);
    select id, debt_usd, total_paid_usd, filial into v_dealer from public.dealers where id = (p_record->>'dealer_id')::bigint for update;
    if not found then raise exception 'CASHBOX: diller topilmadi' using errcode = 'P0001'; end if;
    if coalesce(v_dealer.filial, 'baza') <> p_filial then raise exception 'CASHBOX: diller boshqa filialga tegishli' using errcode = 'P0001'; end if;
  end if;

  v_res := public.cashbox_apply_ops(p_filial, p_group_key, p_kind, p_ops, p_staff_id, p_staff_name);
  if coalesce((v_res->>'replay')::boolean, false) then
    if p_record_type = 'dealer_payment' then
      v_extra := jsonb_build_object('dealerDebtUsd', v_dealer.debt_usd, 'dealerTotalPaidUsd', v_dealer.total_paid_usd);
    end if;
    return v_res || v_extra;   -- yozuv birinchi chaqiruvda (shu tranzaksiyada) qo'shilgan
  end if;

  if p_record_type = 'customer_debt_payment' then
    insert into public.customer_debt_payments (filial, customer_local_id, customer_name, amount_uzs, box_local_id, staff_id, staff_name, idem_key)
    values (p_filial, (p_record->>'customer_local_id')::bigint, left(p_record->>'customer_name', 200), (p_record->>'amount_uzs')::numeric,
            (p_record->>'box_local_id')::integer, p_staff_id, left(p_staff_name, 200), p_group_key);
  elsif p_record_type = 'supplier_payment' then
    insert into public.supplier_payments (filial, supplier_local_id, supplier_name, amount_usd, box_local_id, staff_id, staff_name, idem_key)
    values (p_filial, (p_record->>'supplier_local_id')::bigint, left(p_record->>'supplier_name', 200), (p_record->>'amount_usd')::numeric,
            (p_record->>'box_local_id')::integer, p_staff_id, left(p_staff_name, 200), p_group_key);
  elsif p_record_type = 'home_withdrawal' then
    insert into public.home_withdrawals (filial, entries, note, staff_id, staff_name, idem_key)
    values (p_filial, coalesce(p_record->'entries', '[]'::jsonb), left(p_record->>'note', 500), p_staff_id, left(p_staff_name, 200), p_group_key);
  else
    v_debt := coalesce(v_dealer.debt_usd, 0);
    if v_amt is null or v_amt <= 0 or v_amt > v_debt + 0.01 then
      raise exception 'CASHBOX: to''lov (% $) diller qarzidan (% $) oshib ketdi', v_amt, v_debt using errcode = 'P0001';
    end if;
    insert into public.dealer_payments (dealer_id, amount_usd, note, idem_key)
    values (v_dealer.id, v_amt, left(p_record->>'note', 300), p_group_key);
    update public.dealers set debt_usd = greatest(round(debt_usd - v_amt, 2), 0), total_paid_usd = coalesce(total_paid_usd, 0) + v_amt
     where id = v_dealer.id
     returning debt_usd, total_paid_usd into v_dealer.debt_usd, v_dealer.total_paid_usd;
    v_extra := jsonb_build_object('dealerDebtUsd', v_dealer.debt_usd, 'dealerTotalPaidUsd', v_dealer.total_paid_usd);
  end if;
  return v_res || v_extra;
end;
$$;

-- ── 6. Ruxsatlar: yangi funksiyalar — faqat server ────────────────────
revoke all on function public._fk_source_type(text, text, text) from public, anon, authenticated;
revoke all on function public._fk_ledger_defaults() from public, anon, authenticated;
revoke all on function public._ledger_immutable() from public, anon, authenticated;
revoke all on function public.firma_kassa_reverse(bigint, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.branch_firma_loan(text, integer, text, text, numeric, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_branch_summary(text) from public, anon, authenticated;
revoke all on function public.cash_payment_atomic(text, text, text, jsonb, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_advance_outstanding(text, text, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_get_balance() from public, anon, authenticated;
grant execute on function public._fk_source_type(text, text, text) to service_role;
grant execute on function public.firma_kassa_reverse(bigint, text, text, bigint, text) to service_role;
grant execute on function public.branch_firma_loan(text, integer, text, text, numeric, text, text, text, bigint, text) to service_role;
grant execute on function public.firma_kassa_branch_summary(text) to service_role;
grant execute on function public.cash_payment_atomic(text, text, text, jsonb, text, jsonb, bigint, text) to service_role;
grant execute on function public.firma_kassa_advance_outstanding(text, text, text) to service_role;
grant execute on function public.firma_kassa_get_balance() to service_role;

-- ── 7. Xavfsizlik: brauzer ishlatmaydigan narsalardan ruxsatlar olinadi ──
-- (Hozir RLS bu jadvallarni to'sib turibdi — production'da anon bilan sinaldi: 0 qator.
--  Bu — ikkinchi qatlam: bitta xato policy butun jadvalni ochib yubormasligi uchun.)
revoke all on public.partners, public.partner_ledger, public.partner_ledger_legacy_history, public.partner_payments,
  public.partner_periods, public.partner_balances, public.partner_monthly_report_summary, public.partner_monthly_report_detail,
  public.bot_sessions, public.login_security
from anon, authenticated;
-- Diller portali (authenticated): faqat o'qish (+ buyurtma yaratish) — policy'lar shunga mos
revoke all on public.dealers, public.dealer_stock, public.dealer_sales, public.dealer_payments, public.catalog_products, public.dealer_orders from anon;
revoke insert, update, delete, truncate, references, trigger on public.dealers, public.dealer_stock, public.dealer_sales,
  public.dealer_payments, public.catalog_products from authenticated;
revoke update, delete, truncate, references, trigger on public.dealer_orders from authenticated;
-- Kirish blokirovkasi funksiyalari ilovada ishlatilmaydi (Supabase Auth o'zi himoya qiladi);
-- SECURITY INVOKER bo'lgani uchun anon ular orqali baribir hech narsa qila olmaydi (RLS) —
-- EXECUTE ortiqcha. O'chirilmaydi (loyiha qoidasi).
revoke execute on function public.login_check_lock(text) from public, anon, authenticated;
revoke execute on function public.login_record_failure(text) from public, anon, authenticated;
revoke execute on function public.login_record_success(text) from public, anon, authenticated;
grant execute on function public.login_check_lock(text) to service_role;
grant execute on function public.login_record_failure(text) to service_role;
grant execute on function public.login_record_success(text) to service_role;

-- ── 8. Hamkorlar SQL jadvallari — eskirgan (ilova ishlatmaydi) ──────────
comment on table public.partners is 'ESKIRGAN (v23): Hamkorlar (investor/ta''sischi) moduli app_data.data.partners (JSON) dan ishlaydi. Bu jadval faqat tarix uchun; yozilmaydi.';
comment on table public.partner_ledger is 'ESKIRGAN (v23): haqiqiy manba — app_data.data.partners/partnerPeriods va filial xarajatlari (turi=hamkor).';
comment on table public.partner_periods is 'ESKIRGAN (v23): haqiqiy manba — app_data.data.partnerPeriods.';
comment on table public.partner_payments is 'ESKIRGAN (v23): hamkor to''lovlari — firma_kassa_ledger (partner_withdrawal) yoki filial xarajatlari.';
comment on table public.firma_kassa_ledger is 'Firma kassasi jurnali: o''zgarmas; bekor qilish faqat teskari yozuv (firma_kassa_reverse).';
comment on table public.cashbox_ledger is 'Filial kassalari jurnali: o''zgarmas; har bir qoldiq o''zgarishi shu yerda.';

-- ────────────────────────────────────────────────────────────────────
-- 10. 26-migratsiya: XARAJAT KATEGORIYALARI — foydalanuvchi yaratadi (expense_categories)
-- (supabase-migration-26-expense-categories.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 26-migratsiya (2026-10-02): XARAJAT KATEGORIYALARI — foydalanuvchi o'zi yaratadi.
-- 23/24/25-migratsiyalardan keyin qo'llanadi. Takroriy ishga tushirish xavfsiz.
-- Ma'lumot o'chirilmaydi: faqat yangi jadval, funksiya va indekslar qo'shiladi.
--
-- Avval kategoriyalar kodda qotirilgan edi (Svet, Yo'lkira, Ijara, Soliq, Boshqa ...).
-- Endi kategoriya: filialning o'zi (filial avtonom), xarajat turi bo'yicha
-- (dokon / tasischi / hamkor). Yozish va o'qish FAQAT server orqali
-- (netlify/functions/expense-categories.js, service_role) — brauzerga jadval yopiq.
--
--  • Nom: bo'shliqlar bitta qilinadi va chetlari kesiladi; 1–60 belgi.
--  • Takror: filial + tur ichida, FAOL kategoriyalar orasida, katta-kichik harf va
--    apostrof turi (' ʻ ʼ ‘ ’ ` ´) farqsiz — "  Elektr " = "elektr".
--  • O'chirish: xarajatlarda ishlatilgan bo'lsa — faqat nofaol (is_active=false),
--    tarixiy xarajatlar o'z kategoriyasi bilan qoladi; ishlatilmagan bo'lsa — o'chiriladi.
--  • Nomni o'zgartirish: ID o'zgarmaydi (xarajatlar catId orqali bog'langan).
--  • Kategoriya hech qanday pul jadvaliga (kassa, Firma kassa, qarz, savdo) bog'lanmagan.
-- ════════════════════════════════════════════════════════════════════

-- Unicode apostroflarni (ʻ ʼ ‘ ’) to'g'ri solishtirish uchun baza UTF8 bo'lishi shart (Supabase — doim UTF8).
do $$ begin
  if pg_encoding_to_char((select encoding from pg_database where datname = current_database())) <> 'UTF8' then
    raise exception '26-migratsiya: baza kodlashi UTF8 bo''lishi kerak (hozir %)', pg_encoding_to_char((select encoding from pg_database where datname = current_database()));
  end if;
end $$;

-- Taqqoslash kaliti: bo'shliq normallashtiriladi, apostroflar bitta, kichik harf
create or replace function public._expense_cat_key(p_name text)
 returns text
 language sql
 immutable
 set search_path = ''
as $$
  select lower(btrim(regexp_replace(translate(coalesce(p_name, ''), 'ʻʼ‘’`´', repeat(chr(39), 6)), '\s+', ' ', 'g')));
$$;

create table if not exists public.expense_categories (
  id                  bigint generated always as identity primary key,
  filial              text not null,
  turi                text not null default 'dokon',
  name                text not null,
  name_key            text generated always as (public._expense_cat_key(name)) stored,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          bigint references public.staff(id) on delete set null,
  created_by_name     text,
  updated_by_name     text,
  deactivated_at      timestamptz,
  deactivated_by_name text,
  idem_key            text,
  constraint expense_categories_filial_chk check (filial ~ '^[A-Za-z0-9_-]{1,40}$'),
  constraint expense_categories_turi_chk   check (turi in ('dokon', 'tasischi', 'hamkor')),
  constraint expense_categories_name_chk   check (char_length(name) between 1 and 60 and name = btrim(name) and name !~ '\s{2,}'),
  constraint expense_categories_inactive_chk check (is_active or deactivated_at is not null),
  constraint expense_categories_meta_len   check (coalesce(length(created_by_name), 0) <= 200 and coalesce(length(updated_by_name), 0) <= 200
                                                  and coalesce(length(deactivated_by_name), 0) <= 200 and coalesce(length(idem_key), 0) <= 100)
);

-- Faol kategoriyalar orasida takror yo'q (nofaol bo'lgani bilan bir xil nomli yangisini yaratish mumkin)
create unique index if not exists expense_categories_active_uq on public.expense_categories (filial, turi, name_key) where is_active;
-- Ikki marta bosish / qayta urinish — bir xil kalit ikkinchi yozuv yaratmaydi
create unique index if not exists expense_categories_idem_uq on public.expense_categories (idem_key) where idem_key is not null;
create index if not exists idx_expense_categories_filial on public.expense_categories (filial, turi, is_active);

-- updated_at avtomatik
create or replace function public._expense_categories_touch()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'expense_categories_touch' and tgrelid = 'public.expense_categories'::regclass) then
    create trigger expense_categories_touch before update on public.expense_categories
      for each row execute function public._expense_categories_touch();
  end if;
end $$;

-- Xavfsizlik: RLS yoqilgan, siyosat YO'Q (anon/authenticated uchun hamma narsa yopiq);
-- faqat server (service_role) o'qiydi va yozadi
alter table public.expense_categories enable row level security;
revoke all on public.expense_categories from public, anon, authenticated;
grant select, insert, update, delete on public.expense_categories to service_role;
grant usage on sequence public.expense_categories_id_seq to service_role;
revoke all on function public._expense_cat_key(text) from public, anon, authenticated;
grant execute on function public._expense_cat_key(text) to service_role;
revoke all on function public._expense_categories_touch() from public, anon, authenticated;

comment on table public.expense_categories is
  'Xarajat kategoriyalari (filial + tur bo''yicha). Foydalanuvchi yaratadi; tayyor ro''yxat yo''q. Faqat server yozadi (expense-categories funksiyasi).';

-- ────────────────────────────────────────────────────────────────────
-- 11. 27-migratsiya: F4b — mijoz/ta'minotchi qarzi va ombor qoldig'i SERVER haqiqiy manba
-- (supabase-migration-27-f4b-ledger-authority.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- Migratsiya 27 (v23.2, 2026-10-02) — F4b: MIJOZ QARZI, TA'MINOTCHI QARZI VA
-- OMBOR QOLDIG'I (sold/qty) — SERVER HAQIQIY MANBA.
-- 24 va 25-migratsiyalardan KEYIN qo'llanadi (26 ga bog'liq emas).
-- Takroriy ishga tushirish xavfsiz. Mavjud ma'lumot o'chirilmaydi.
--
-- MUAMMO (F4b, final gate dalili — tests/evidence/f4b-gap-evidence.js):
--  • mijoz va ta'minotchi qarzi, partiya qoldig'i (sold/qty) BRAUZERDA hisoblanib,
--    JSON (app_data_branches) sifatida saqlanardi; server to'lov chegarasini shu
--    eskirgan JSON'dan tekshirardi → ikki qurilmadan qarzdan ortiq to'lov o'tardi;
--  • brauzerning eski nusxasi SQL partiya qoldig'ini qayta yozardi → ortiqcha sotuv.
--
-- YECHIM (F4 — kassa — bilan bir xil yondashuv; yangi parallel buxgalteriya yo'q):
--  1) customer_balances (so'm) va supplier_balances ($) — HAQIQIY qoldiq. Yozish faqat
--     _cust_debt_move / _supp_debt_move orqali (trigger boshqa yozishni rad etadi),
--     har bir o'zgarish o'zgarmas jurnalga (customer_debt_ledger / supplier_debt_ledger).
--  2) batches — qty/sold/status/tannarx faqat _stock_move / _batch_insert orqali
--     (trigger), har bir harakat stock_ledger'da; FIFO serverda, qator qulfi bilan.
--  3) sales — savdo hujjati serverda (local_id bilan); qaytarish, tahrir va o'chirish
--     SERVERDAGI savdo yozuvidan hisoblanadi (brauzer yuborgan summa emas).
--  4) Murakkab amallar (savdo, qaytarish, kirim, reviziya, ko'chirish...) — BITTA
--     tranzaksiyada: kassa + qarz + ombor; ledger_ops orqali idempotent (takror → replay).
--  5) cash_payment_atomic — mijoz/ta'minotchi qarzi qatori QULFLANADI va qarzdan ortiq
--     to'lov bazada rad etiladi (kassa harakati ham bekor bo'ladi).
--  6) Filialning Bazaga tovar qarzi (app_data.branchDebt) — sotuvda serverda oshadi.
--  7) Boshlang'ich qiymatlar hozirgi JSON'dan BIR MARTA ko'chiriladi ('opening' yozuvi).
--
-- Kirish: faqat server (service_role). Brauzer (anon/authenticated) — yo'q.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.cashbox_ledger') is null or not exists (select 1 from pg_proc where proname = 'cash_payment_atomic') then
    raise exception '27-migratsiya: avval 24 va 25-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Ustunlar (faqat qo'shiladi) ─────────────────────────────────────
alter table public.customer_balances add column if not exists currency text not null default 'UZS';
alter table public.supplier_balances add column if not exists currency text not null default 'USD';
alter table public.supplier_balances add column if not exists total_paid numeric not null default 0;

alter table public.batches add column if not exists from_branch text;
alter table public.batches add column if not exists kirim_ref text;
alter table public.batches add column if not exists fk_ref text;
alter table public.batches add column if not exists arrived_at date;
alter table public.batches add column if not exists deleted_at timestamp with time zone;
alter table public.batches add column if not exists edited_at timestamp with time zone;

alter table public.sales add column if not exists local_id text;
alter table public.sales add column if not exists pay_type text;
alter table public.sales add column if not exists box_id integer;
alter table public.sales add column if not exists mixed_rows jsonb;
alter table public.sales add column if not exists cust_name text;
alter table public.sales add column if not exists disc_usd numeric;
alter table public.sales add column if not exists sale_date date;
alter table public.sales add column if not exists status text not null default 'done';
alter table public.sales add column if not exists voided_at timestamp with time zone;
alter table public.sales add column if not exists edited_at timestamp with time zone;
alter table public.sales add column if not exists staff_id bigint;
alter table public.sales add column if not exists staff_name text;
alter table public.sales add column if not exists is_transfer boolean not null default false;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'customer_balances_currency_chk' and conrelid = 'public.customer_balances'::regclass) then
    alter table public.customer_balances add constraint customer_balances_currency_chk check (currency = 'UZS');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'supplier_balances_currency_chk' and conrelid = 'public.supplier_balances'::regclass) then
    alter table public.supplier_balances add constraint supplier_balances_currency_chk check (currency = 'USD');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sales_status_chk' and conrelid = 'public.sales'::regclass) then
    alter table public.sales add constraint sales_status_chk check (status in ('done','voided'));
  end if;
end $$;

create unique index if not exists sales_filial_local_id_uq on public.sales (filial, local_id) where local_id is not null;
create index if not exists idx_batches_fifo on public.batches (filial, pid, status, batch_date, id);

-- ── 2. Jurnallar (o'zgarmas) va amallar ro'yxati ──────────────────────
create table if not exists public.customer_debt_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  customer_local_id bigint not null,
  delta numeric(20,2) not null,
  balance_after numeric(20,2) not null,
  op_kind text not null,
  op_key text not null,
  group_key text,
  ref_type text,
  ref_id text,
  note text,
  staff_id bigint,
  staff_name text,
  constraint customer_debt_ledger_op_key_key unique (filial, op_key),
  constraint customer_debt_ledger_kind_chk check (op_kind in ('opening','adjust','sale','sale_edit','sale_void','sale_return','payment')),
  constraint customer_debt_ledger_delta_chk check (delta <> 0 or op_kind = 'opening'),
  constraint customer_debt_ledger_text_len check (length(op_key) <= 160 and coalesce(length(note),0) <= 500
    and coalesce(length(staff_name),0) <= 200 and coalesce(length(ref_id),0) <= 100)
);
create index if not exists idx_cust_debt_ledger_party on public.customer_debt_ledger (filial, customer_local_id, id desc);

create table if not exists public.supplier_debt_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  supplier_local_id bigint not null,
  delta numeric(20,4) not null,
  paid_delta numeric(20,4) not null default 0,
  balance_after numeric(20,4) not null,
  op_kind text not null,
  op_key text not null,
  group_key text,
  ref_type text,
  ref_id text,
  note text,
  staff_id bigint,
  staff_name text,
  constraint supplier_debt_ledger_op_key_key unique (filial, op_key),
  constraint supplier_debt_ledger_kind_chk check (op_kind in ('opening','adjust','sale_direct','consignment','sale_return','kirim','import','batch_edit','payment')),
  constraint supplier_debt_ledger_delta_chk check (delta <> 0 or paid_delta <> 0 or op_kind = 'opening'),
  constraint supplier_debt_ledger_text_len check (length(op_key) <= 160 and coalesce(length(note),0) <= 500
    and coalesce(length(staff_name),0) <= 200 and coalesce(length(ref_id),0) <= 100)
);
create index if not exists idx_supp_debt_ledger_party on public.supplier_debt_ledger (filial, supplier_local_id, id desc);

create table if not exists public.stock_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  batch_id bigint not null references public.batches(id) on delete restrict,
  batch_local_id text not null,
  pid bigint not null,
  d_qty numeric not null default 0,
  d_sold numeric not null default 0,
  qty_after numeric not null,
  sold_after numeric not null,
  cost_usd numeric,
  status_after text,
  op_kind text not null,
  op_key text not null,
  group_key text,
  ref_type text,
  ref_id text,
  note text,
  staff_id bigint,
  staff_name text,
  constraint stock_ledger_op_key_key unique (filial, op_key),
  constraint stock_ledger_kind_chk check (op_kind in ('opening','archive','sale','sale_edit','sale_void','sale_return','kirim','import',
    'opening_stock','edit','delete','arrive','revision','transfer_out','transfer_in','dealer_out','dealer_return')),
  constraint stock_ledger_text_len check (length(op_key) <= 200 and coalesce(length(note),0) <= 500
    and coalesce(length(staff_name),0) <= 200 and coalesce(length(ref_id),0) <= 100)
);
create index if not exists idx_stock_ledger_batch on public.stock_ledger (batch_id, id desc);
create index if not exists idx_stock_ledger_ref on public.stock_ledger (filial, ref_type, ref_id) where ref_id is not null;

create table if not exists public.ledger_ops (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  op_key text not null,
  kind text not null,
  result jsonb not null,
  staff_id bigint,
  staff_name text,
  constraint ledger_ops_op_key_key unique (filial, op_key),
  constraint ledger_ops_kind_chk check (kind in ('sale','sale_return','sale_void','sale_edit','cust_set','supp_set',
    'batches_create','batch_edit','batch_delete','batch_arrive','revision','stock_out')),
  constraint ledger_ops_text_len check (length(op_key) <= 140 and coalesce(length(staff_name),0) <= 200)
);

create or replace trigger customer_debt_ledger_immutable before update or delete on public.customer_debt_ledger
  for each row execute function public._ledger_immutable();
create or replace trigger supplier_debt_ledger_immutable before update or delete on public.supplier_debt_ledger
  for each row execute function public._ledger_immutable();
create or replace trigger stock_ledger_immutable before update or delete on public.stock_ledger
  for each row execute function public._ledger_immutable();
create or replace trigger ledger_ops_immutable before update or delete on public.ledger_ops
  for each row execute function public._ledger_immutable();

alter table public.customer_debt_ledger enable row level security;
alter table public.supplier_debt_ledger enable row level security;
alter table public.stock_ledger enable row level security;
alter table public.ledger_ops enable row level security;
revoke all on public.customer_debt_ledger, public.supplier_debt_ledger, public.stock_ledger, public.ledger_ops from anon, authenticated;
grant select, insert on public.customer_debt_ledger, public.supplier_debt_ledger, public.stock_ledger, public.ledger_ops to service_role;
grant usage on sequence public.customer_debt_ledger_id_seq, public.supplier_debt_ledger_id_seq, public.stock_ledger_id_seq, public.ledger_ops_id_seq to service_role;
-- Qoldiq jadvallari ham brauzerga yopiq (ikkinchi himoya qatlami; RLS allaqachon yoqilgan)
revoke all on public.customer_balances, public.supplier_balances, public.batches, public.sales from anon, authenticated;

-- ── 3. Qoldiqlarni faqat jurnal orqali o'zgartirish (triggerlar) ──────
create or replace function public._debt_balances_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if coalesce(current_setting('fw.debt_move', true), '') = '1' then
    return coalesce(new, old);
  end if;
  if tg_op = 'INSERT' and coalesce(new.debt, 0) = 0 then
    return new;                                   -- bo'sh (0) qator — xavfsiz
  end if;
  if tg_op = 'UPDATE' and new.debt is not distinct from old.debt
     and (tg_table_name <> 'supplier_balances' or (to_jsonb(new)->'total_paid') is not distinct from (to_jsonb(old)->'total_paid')) then
    return new;                                   -- qarz o'zgarmagan
  end if;
  raise exception 'LEDGER: qarz faqat qarz jurnali orqali o''zgaradi' using errcode = 'P0001';
end;
$$;
create or replace trigger customer_balances_guard before insert or update or delete on public.customer_balances
  for each row execute function public._debt_balances_guard();
create or replace trigger supplier_balances_guard before insert or update or delete on public.supplier_balances
  for each row execute function public._debt_balances_guard();

create or replace function public._batches_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if coalesce(current_setting('fw.stock_move', true), '') = '1' then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' then
    raise exception 'LEDGER: partiyani o''chirib bo''lmaydi (holati "deleted" bo''ladi)' using errcode = 'P0001';
  end if;
  if tg_op = 'INSERT' then
    if coalesce(new.qty, 0) = 0 and coalesce(new.sold, 0) = 0 then return new; end if;
    raise exception 'LEDGER: ombor qoldig''i faqat ombor jurnali (stock_ledger) orqali o''zgaradi' using errcode = 'P0001';
  end if;
  if new.qty is not distinct from old.qty and new.sold is not distinct from old.sold
     and new.status is not distinct from old.status and new.cost_usd is not distinct from old.cost_usd
     and new.supp_id is not distinct from old.supp_id and new.consignment is not distinct from old.consignment
     and new.from_branch is not distinct from old.from_branch and new.filial is not distinct from old.filial
     and new.pid is not distinct from old.pid and new.local_id is not distinct from old.local_id then
    return new;                                   -- faqat izoh/meta o'zgargan
  end if;
  raise exception 'LEDGER: ombor qoldig''i faqat ombor jurnali (stock_ledger) orqali o''zgaradi' using errcode = 'P0001';
end;
$$;
create or replace trigger batches_guard before insert or update or delete on public.batches
  for each row execute function public._batches_guard();

-- ── 4. Yordamchi funksiyalar ───────────────────────────────────────────
create or replace function public._fw_num(p text)
 returns numeric
 language sql
 immutable
 set search_path = ''
as $$
  select case when p ~ '^\s*-?[0-9]{1,18}(\.[0-9]{1,40})?([eE][-+]?[0-9]{1,2})?\s*$' then trim(p)::numeric else 0 end;
$$;

create or replace function public._fw_rate()
 returns numeric
 language plpgsql
 stable
 set search_path = ''
as $$
declare v numeric;
begin
  select nullif(public._fw_num(data->'settings'->>'usdUzs'), 0) into v from public.app_data where id = 'main';
  if v is null or v <= 0 then
    raise exception 'LEDGER: USD/UZS kursi sozlanmagan' using errcode = 'P0001';
  end if;
  return v;
end;
$$;

-- Mijoz qarzi (so'm). p_mode: 'strict' — kamayish qarzdan (1 so'm chegarasi bilan) oshsa rad;
-- 'clamp' — 0 dan pastga tushmaydi (teskari amallar, avvalgi qoida: Math.max(0, ...));
-- 'set' — qo'lda belgilangan qiymat (boshlang'ich / tahrir; faqat ruxsatli xodim).
create or replace function public._cust_debt_move(
  p_filial text, p_cust bigint, p_delta numeric, p_mode text, p_kind text, p_op_key text,
  p_group_key text default null, p_ref_type text default null, p_ref_id text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns numeric
 language plpgsql
 set search_path = ''
as $$
declare
  v_bal numeric;
  v_new numeric;
begin
  if coalesce(p_filial, '') = '' or p_cust is null or p_cust <= 0 then
    raise exception 'LEDGER: mijoz noto''g''ri' using errcode = 'P0001';
  end if;
  if p_delta is null or p_delta = 'NaN'::numeric or abs(p_delta) > 1000000000000000 then
    raise exception 'LEDGER: qarz summasi noto''g''ri' using errcode = 'P0001';
  end if;
  perform set_config('fw.debt_move', '1', true);
  insert into public.customer_balances (filial, customer_local_id, debt, currency) values (p_filial, p_cust, 0, 'UZS')
    on conflict (filial, customer_local_id) do nothing;
  select debt into v_bal from public.customer_balances where filial = p_filial and customer_local_id = p_cust for update;
  v_bal := coalesce(v_bal, 0);
  if p_mode = 'set' then
    v_new := round(p_delta, 2);
    if v_new < 0 then raise exception 'LEDGER: qarz manfiy bo''lishi mumkin emas' using errcode = 'P0001'; end if;
  elsif p_mode = 'strict' then
    v_new := round(v_bal + p_delta, 2);
    if v_new < -1 then
      raise exception 'LEDGER: to''lov (% so''m) mijoz qarzidan (% so''m) oshib ketdi', round(-p_delta), round(v_bal) using errcode = 'P0001';
    end if;
    v_new := greatest(v_new, 0);
  elsif p_mode = 'clamp' then
    v_new := greatest(round(v_bal + p_delta, 2), 0);
  else
    raise exception 'LEDGER: noma''lum rejim' using errcode = 'P0001';
  end if;
  update public.customer_balances set debt = v_new, updated_at = now() where filial = p_filial and customer_local_id = p_cust;
  if v_new <> v_bal or p_kind = 'opening' then
    insert into public.customer_debt_ledger (filial, customer_local_id, delta, balance_after, op_kind, op_key, group_key, ref_type, ref_id, note, staff_id, staff_name)
    values (p_filial, p_cust, v_new - v_bal, v_new, p_kind, p_op_key, p_group_key, left(p_ref_type, 40), left(p_ref_id, 100), left(p_note, 500), p_staff_id, left(p_staff_name, 200));
  end if;
  perform set_config('fw.debt_move', '', true);
  return v_new;
end;
$$;

-- Ta'minotchi qarzi ($). Rejimlar — yuqoridagi kabi (chegara 0.01 $). p_paid_delta — jami to'langan.
create or replace function public._supp_debt_move(
  p_filial text, p_supp bigint, p_delta numeric, p_paid_delta numeric, p_mode text, p_kind text, p_op_key text,
  p_group_key text default null, p_ref_type text default null, p_ref_id text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns numeric
 language plpgsql
 set search_path = ''
as $$
declare
  v_bal numeric;
  v_new numeric;
  v_paid numeric := round(coalesce(p_paid_delta, 0), 4);
begin
  if coalesce(p_filial, '') = '' or p_supp is null or p_supp <= 0 then
    raise exception 'LEDGER: ta''minotchi noto''g''ri' using errcode = 'P0001';
  end if;
  if p_delta is null or p_delta = 'NaN'::numeric or abs(p_delta) > 1000000000000 or v_paid < 0 then
    raise exception 'LEDGER: qarz summasi noto''g''ri' using errcode = 'P0001';
  end if;
  perform set_config('fw.debt_move', '1', true);
  insert into public.supplier_balances (filial, supplier_local_id, debt, currency) values (p_filial, p_supp, 0, 'USD')
    on conflict (filial, supplier_local_id) do nothing;
  select debt into v_bal from public.supplier_balances where filial = p_filial and supplier_local_id = p_supp for update;
  v_bal := coalesce(v_bal, 0);
  if p_mode = 'set' then
    v_new := round(p_delta, 4);
    if v_new < 0 then raise exception 'LEDGER: qarz manfiy bo''lishi mumkin emas' using errcode = 'P0001'; end if;
  elsif p_mode = 'strict' then
    v_new := round(v_bal + p_delta, 4);
    if v_new < -0.01 then
      raise exception 'LEDGER: to''lov (% $) ta''minotchi qarzidan (% $) oshib ketdi', round(-p_delta, 2), round(v_bal, 2) using errcode = 'P0001';
    end if;
    v_new := greatest(v_new, 0);
  elsif p_mode = 'clamp' then
    v_new := greatest(round(v_bal + p_delta, 4), 0);
  else
    raise exception 'LEDGER: noma''lum rejim' using errcode = 'P0001';
  end if;
  update public.supplier_balances set debt = v_new, total_paid = total_paid + v_paid, updated_at = now()
   where filial = p_filial and supplier_local_id = p_supp;
  if v_new <> v_bal or v_paid <> 0 or p_kind = 'opening' then
    insert into public.supplier_debt_ledger (filial, supplier_local_id, delta, paid_delta, balance_after, op_kind, op_key, group_key, ref_type, ref_id, note, staff_id, staff_name)
    values (p_filial, p_supp, v_new - v_bal, v_paid, v_new, p_kind, p_op_key, p_group_key, left(p_ref_type, 40), left(p_ref_id, 100), left(p_note, 500), p_staff_id, left(p_staff_name, 200));
  end if;
  perform set_config('fw.debt_move', '', true);
  return v_new;
end;
$$;

-- Partiya harakati: d_qty / d_sold; sold ≤ qty, manfiy bo'lmaydi; holat (active/empty) avtomatik.
create or replace function public._stock_move(
  p_batch_id bigint, p_d_qty numeric, p_d_sold numeric, p_kind text, p_op_key text,
  p_group_key text default null, p_ref_type text default null, p_ref_id text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null, p_new_status text default null, p_new_cost numeric default null)
 returns public.batches
 language plpgsql
 set search_path = ''
as $$
declare
  b public.batches;
  v_qty numeric;
  v_sold numeric;
  v_status text;
begin
  select * into b from public.batches where id = p_batch_id for update;
  if not found then raise exception 'LEDGER: partiya topilmadi' using errcode = 'P0001'; end if;
  if b.status = 'deleted' then raise exception 'LEDGER: partiya o''chirilgan (%)', b.local_id using errcode = 'P0001'; end if;
  v_qty := b.qty + coalesce(p_d_qty, 0);
  v_sold := b.sold + coalesce(p_d_sold, 0);
  if v_qty < -0.000001 or v_sold < -0.000001 or v_qty > 100000000 then
    raise exception 'LEDGER: partiya miqdori noto''g''ri (%)', b.local_id using errcode = 'P0001';
  end if;
  if v_sold > v_qty + 0.000001 then
    raise exception 'LEDGER: omborda yetarli qoldiq yo''q (partiya %: bor %, kerak %)', b.local_id, b.qty - b.sold, coalesce(p_d_sold, 0) - coalesce(p_d_qty, 0) using errcode = 'P0001';
  end if;
  if p_new_cost is not null and (p_new_cost < 0 or p_new_cost > 10000000) then
    raise exception 'LEDGER: tannarx noto''g''ri' using errcode = 'P0001';
  end if;
  v_status := coalesce(p_new_status, b.status);
  if v_status is null or v_status in ('active','empty') then
    v_status := case when v_qty - v_sold <= 0.000001 then 'empty' else 'active' end;
  end if;
  perform set_config('fw.stock_move', '1', true);
  update public.batches
     set qty = v_qty, sold = v_sold, status = v_status, cost_usd = coalesce(p_new_cost, cost_usd), updated_at = now(),
         edited_at = case when p_kind in ('edit','arrive') then now() else edited_at end,
         arrived_at = case when p_kind = 'arrive' then current_date else arrived_at end,
         deleted_at = case when v_status = 'deleted' then now() else deleted_at end
   where id = b.id
   returning * into b;
  insert into public.stock_ledger (filial, batch_id, batch_local_id, pid, d_qty, d_sold, qty_after, sold_after, cost_usd, status_after,
                                   op_kind, op_key, group_key, ref_type, ref_id, note, staff_id, staff_name)
  values (b.filial, b.id, b.local_id, b.pid, coalesce(p_d_qty, 0), coalesce(p_d_sold, 0), b.qty, b.sold, b.cost_usd, b.status,
          p_kind, p_op_key, p_group_key, left(p_ref_type, 40), left(p_ref_id, 100), left(p_note, 500), p_staff_id, left(p_staff_name, 200));
  perform set_config('fw.stock_move', '', true);
  return b;
end;
$$;

-- Yangi partiya (kirim, qaytarish, boshlang'ich qoldiq, ko'chirish). p_meta — izoh maydonlari.
create or replace function public._batch_insert(
  p_filial text, p_local_id text, p_pid bigint, p_qty numeric, p_cost numeric, p_status text, p_meta jsonb,
  p_kind text, p_op_key text, p_group_key text default null, p_ref_type text default null, p_ref_id text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns public.batches
 language plpgsql
 set search_path = ''
as $$
declare
  b public.batches;
  m jsonb := coalesce(p_meta, '{}'::jsonb);
  v_date date;
begin
  if coalesce(p_filial, '') = '' or coalesce(p_local_id, '') !~ '^[0-9A-Za-z_.:-]{1,64}$' then
    raise exception 'LEDGER: partiya ID noto''g''ri' using errcode = 'P0001';
  end if;
  if p_pid is null or p_pid <= 0 then raise exception 'LEDGER: mahsulot noto''g''ri' using errcode = 'P0001'; end if;
  if p_qty is null or p_qty = 'NaN'::numeric or p_qty <= 0 or p_qty > 10000000 then
    raise exception 'LEDGER: miqdor musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  if p_cost is null or p_cost = 'NaN'::numeric or p_cost < 0 or p_cost > 10000000 then
    raise exception 'LEDGER: tannarx noto''g''ri' using errcode = 'P0001';
  end if;
  if coalesce(p_status, 'active') not in ('active','transit') then
    raise exception 'LEDGER: partiya holati noto''g''ri' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.batches where filial = p_filial and local_id = p_local_id) then
    raise exception 'LEDGER: partiya ID takrorlandi (%)', p_local_id using errcode = 'P0001';
  end if;
  v_date := case when coalesce(m->>'date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (m->>'date')::date else current_date end;
  perform set_config('fw.stock_move', '1', true);
  insert into public.batches (local_id, filial, pid, bno, origin, cur, qty, sold, cost_usd, bank_fee_usd, supp_id, consignment,
                              rate_usd_uzs, rate_usd_cny, batch_date, status, performed_by, from_branch, kirim_ref, fk_ref, arrived_at)
  values (p_local_id, p_filial, p_pid, left(m->>'bno', 20), left(m->>'origin', 300),
          case when m->>'cur' in ('USD','UZS','CNY','KRW') then m->>'cur' else 'USD' end,
          p_qty, 0, p_cost, greatest(public._fw_num(m->>'bankFeeUsd'), 0),
          case when coalesce(m->>'suppId', '') ~ '^[0-9]{1,18}$' then (m->>'suppId')::bigint end,
          coalesce((m->>'consignment')::boolean, false),
          nullif(public._fw_num(m->>'rateUsdUzs'), 0), nullif(public._fw_num(m->>'rateUsdCny'), 0),
          v_date, coalesce(p_status, 'active'), left(m->>'performedBy', 200),
          case when m->>'fromBranch' ~ '^[a-z0-9_]{1,40}$' then m->>'fromBranch' end,
          left(m->>'kirimRef', 64), left(m->>'fkRef', 64),
          case when coalesce(p_status, 'active') = 'active' then v_date end)
  returning * into b;
  insert into public.stock_ledger (filial, batch_id, batch_local_id, pid, d_qty, d_sold, qty_after, sold_after, cost_usd, status_after,
                                   op_kind, op_key, group_key, ref_type, ref_id, note, staff_id, staff_name)
  values (b.filial, b.id, b.local_id, b.pid, b.qty, 0, b.qty, 0, b.cost_usd, b.status,
          p_kind, p_op_key, p_group_key, left(p_ref_type, 40), left(p_ref_id, 100), left(m->>'origin', 500), p_staff_id, left(p_staff_name, 200));
  perform set_config('fw.stock_move', '', true);
  return b;
end;
$$;

-- Filialning Bazaga tovar qarzi (app_data.branchDebt, $) — faqat server oshiradi
create or replace function public._branch_debt_add(p_filial text, p_usd numeric)
 returns numeric
 language plpgsql
 set search_path = ''
as $$
declare v numeric;
begin
  if p_usd is null or p_usd = 0 or p_filial = 'baza' then return null; end if;
  update public.app_data
     set data = jsonb_set(data, '{branchDebt}', coalesce(data->'branchDebt', '{}'::jsonb)
                || jsonb_build_object(p_filial, round(public._fw_num(data->'branchDebt'->>p_filial) + p_usd, 4))),
         updated_at = now()
   where id = 'main'
   returning public._fw_num(data->'branchDebt'->>p_filial) into v;
  return v;
end;
$$;

-- FIFO bo'yicha ombordan chiqarish (eng eski partiyadan), qator qulfi bilan.
-- Ta'minotchi qarzi (konsignatsiya) va filialning Bazaga qarzi bu yerda YOZILMAYDI — ular "side"
-- sifatida qaytariladi va chaqiruvchi BARCHA ombor qulflaridan KEYIN qo'llaydi (_fw_apply_side_debts):
-- qulflash tartibi doim bir xil — partiyalar → ta'minotchilar → app_data → mijoz → kassa (deadlock yo'q).
-- Natija: {cost, firstCost, allocs:[{batchId, localId, take, cost}], side:[{supp, usd, kind}], bd}
create or replace function public._stock_fifo_out(
  p_filial text, p_pid bigint, p_qty numeric, p_kind text, p_op_prefix text,
  p_group_key text default null, p_ref_type text default null, p_ref_id text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  b record;
  v_rem numeric := p_qty;
  v_take numeric;
  v_cost numeric := 0;
  v_first numeric := null;
  v_bd numeric := 0;
  v_allocs jsonb := '[]'::jsonb;
  v_side jsonb := '[]'::jsonb;
begin
  if p_qty is null or p_qty = 'NaN'::numeric or p_qty <= 0 or p_qty > 10000000 then
    raise exception 'LEDGER: miqdor musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  -- Avval shu mahsulotning barcha faol partiyalari tartib bilan qulflanadi
  perform 1 from public.batches where filial = p_filial and pid = p_pid and status = 'active'
    order by batch_date asc nulls last, id asc for update;
  for b in
    select id, local_id, qty, sold, cost_usd, consignment, supp_id, from_branch from public.batches
     where filial = p_filial and pid = p_pid and status = 'active' and qty > sold
     order by batch_date asc nulls last, id asc
  loop
    exit when v_rem <= 0.000001;
    v_take := least(b.qty - b.sold, v_rem);
    perform public._stock_move(b.id, 0, v_take, p_kind, p_op_prefix || ':' || b.id, p_group_key, p_ref_type, p_ref_id, p_note, p_staff_id, p_staff_name);
    if v_first is null then v_first := b.cost_usd; end if;
    v_cost := v_cost + v_take * b.cost_usd;
    if b.consignment and b.supp_id is not null then
      v_side := v_side || jsonb_build_object('supp', b.supp_id, 'usd', v_take * b.cost_usd, 'kind', 'consignment');
    end if;
    if b.from_branch = 'baza' and p_filial <> 'baza' then v_bd := v_bd + v_take * b.cost_usd; end if;
    v_allocs := v_allocs || jsonb_build_object('batchId', b.id, 'localId', b.local_id, 'take', v_take, 'cost', b.cost_usd);
    v_rem := v_rem - v_take;
  end loop;
  if v_rem > 0.000001 then
    raise exception 'Omborda yetarli qoldiq yo''q: pid=%, yetishmayotgan miqdor=%', p_pid, v_rem using errcode = 'P0001';
  end if;
  return jsonb_build_object('cost', v_cost, 'firstCost', coalesce(v_first, 0), 'allocs', v_allocs, 'side', v_side, 'bd', v_bd);
end;
$$;

-- Ombor qulflaridan keyin: ta'minotchi qarzlari (id tartibida) va filialning Bazaga qarzi
create or replace function public._fw_apply_side_debts(p_filial text, p_side jsonb, p_bd numeric, p_op_prefix text,
  p_group_key text default null, p_ref_type text default null, p_ref_id text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns bigint[]
 language plpgsql
 set search_path = ''
as $$
declare
  r record;
  v_supps bigint[] := '{}';
begin
  for r in
    select (e->>'supp')::bigint as supp, e->>'kind' as kind, sum(public._fw_num(e->>'usd')) as usd
      from jsonb_array_elements(coalesce(p_side, '[]'::jsonb)) e
     group by 1, 2 order by 1, 2
  loop
    continue when r.usd = 0;
    perform public._supp_debt_move(p_filial, r.supp, r.usd, 0, 'strict', r.kind, p_op_prefix || ':' || r.kind || ':' || r.supp,
      p_group_key, p_ref_type, p_ref_id,
      case r.kind when 'consignment' then 'Konsignatsiya: sotilgan qism' else 'To''g''ridan-to''g''ri savdo (ta''minotchidan)' end,
      p_staff_id, p_staff_name);
    v_supps := v_supps || r.supp;
  end loop;
  if coalesce(p_bd, 0) > 0 then perform public._branch_debt_add(p_filial, p_bd); end if;
  return v_supps;
end;
$$;

-- Javob uchun: berilgan mijoz/ta'minotchi/partiyalarning HAQIQIY qiymatlari
create or replace function public._fw_authority(p_filial text, p_cust bigint[], p_supp bigint[], p_batches bigint[])
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object(
    'filial', p_filial,
    'customers', coalesce((select jsonb_object_agg(customer_local_id::text, debt) from public.customer_balances
                            where filial = p_filial and customer_local_id = any(coalesce(p_cust, '{}'))), '{}'::jsonb),
    'suppliers', coalesce((select jsonb_object_agg(supplier_local_id::text, jsonb_build_object('debt', debt, 'paid', total_paid)) from public.supplier_balances
                            where filial = p_filial and supplier_local_id = any(coalesce(p_supp, '{}'))), '{}'::jsonb),
    'batches', coalesce((select jsonb_agg(jsonb_build_object('filial', filial, 'localId', local_id, 'qty', qty, 'sold', sold, 'status', status, 'costUsd', cost_usd) order by id)
                          from public.batches where id = any(coalesce(p_batches, '{}'))), '[]'::jsonb),
    'branchDebt', coalesce((select data->'branchDebt' from public.app_data where id = 'main'), '{}'::jsonb));
$$;

-- Savdo yozuvi — javob uchun (brauzer formatida)
create or replace function public._fw_sale_json(s public.sales)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object(
    'localId', s.local_id, 'inv', s.inv, 'custId', s.cust_id,
    'subtotalUsd', s.subtotal_usd, 'disc', s.disc_pct, 'discUsd', s.disc_usd, 'totalUsd', s.total_usd,
    'paidUsd', s.paid_usd, 'debtUsd', s.debt_usd, 'profitUsd', s.profit_usd, 'status', s.status,
    'edited', s.edited_at is not null, 'voided', s.voided_at is not null,
    'items', coalesce((select jsonb_agg(jsonb_build_object('pid', public._fw_num(i->>'pid')::bigint, 'qty', public._fw_num(i->>'qty'),
              'sellUsd', public._fw_num(i->>'sell_usd'), 'costUsd', public._fw_num(i->>'cost_usd'),
              'lineUsd', public._fw_num(i->>'qty') * public._fw_num(i->>'sell_usd')) order by o)
              from jsonb_array_elements(s.items) with ordinality as t(i, o)), '[]'::jsonb));
$$;

-- Murakkab amal: takrorni tekshirish (replay) — natija saqlangan bo'lsa, haqiqiy qiymatlar yangilab qaytariladi
create or replace function public._ledger_op_replay(p_filial text, p_op_key text, p_kind text)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  r public.ledger_ops;
  ids jsonb;
begin
  if coalesce(p_op_key, '') !~ '^[A-Za-z0-9:_.-]{3,140}$' then
    raise exception 'LEDGER: amal kaliti noto''g''ri' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtext('fw_lop:' || p_filial || ':' || p_op_key));
  select * into r from public.ledger_ops where filial = p_filial and op_key = p_op_key;
  if not found then return null; end if;
  if r.kind <> p_kind then
    raise exception 'LEDGER: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
  end if;
  ids := coalesce(r.result->'_ids', '{}'::jsonb);
  return (r.result - '_ids') || jsonb_build_object('replay', true, 'authority', public._fw_authority(p_filial,
    array(select jsonb_array_elements_text(coalesce(ids->'c', '[]'::jsonb))::bigint),
    array(select jsonb_array_elements_text(coalesce(ids->'s', '[]'::jsonb))::bigint),
    array(select jsonb_array_elements_text(coalesce(ids->'b', '[]'::jsonb))::bigint)));
end;
$$;

create or replace function public._ledger_op_finish(p_filial text, p_op_key text, p_kind text, p_result jsonb,
  p_cust bigint[], p_supp bigint[], p_batches bigint[], p_staff_id bigint, p_staff_name text)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_auth jsonb := public._fw_authority(p_filial, p_cust, p_supp, p_batches);
begin
  insert into public.ledger_ops (filial, op_key, kind, result, staff_id, staff_name)
  values (p_filial, p_op_key, p_kind, p_result || jsonb_build_object('_ids', jsonb_build_object(
            'c', to_jsonb(coalesce(p_cust, '{}')), 's', to_jsonb(coalesce(p_supp, '{}')), 'b', to_jsonb(coalesce(p_batches, '{}')))),
          p_staff_id, left(p_staff_name, 200));
  return p_result || jsonb_build_object('replay', false, 'authority', v_auth);
end;
$$;
-- ── 5. Savdo (checkout) — ombor + qarz + kassa BITTA tranzaksiyada ─────
-- p_sale: {localId, inv, custId, custName, items:[{pid,sku,name,qty,sellUsd,costUsd,directSupply,suppId}],
--          discPct, paidUsd, payType, boxId, saleDate, isTransfer}
-- Qarz, tannarx, foyda va kassaga tushum SERVERDA hisoblanadi; brauzer yuborgan qarz/qoldiq ishlatilmaydi.
create or replace function public.sale_checkout_atomic_v3(
  p_filial text, p_op_key text, p_sale jsonb, p_box_payments jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  v_item jsonb;
  v_bp jsonb;
  v_items jsonb := '[]'::jsonb;
  v_subtotal numeric := 0;
  v_total numeric;
  v_cost numeric := 0;
  v_profit numeric;
  v_debt numeric;
  v_change numeric;
  v_paid numeric;
  v_disc numeric;
  v_qty numeric;
  v_sell numeric;
  v_icost numeric;
  v_pid bigint;
  v_supp bigint;
  v_cust bigint;
  v_sale public.sales;
  v_fifo jsonb;
  v_side jsonb := '[]'::jsonb;
  v_bd numeric := 0;
  v_custs bigint[] := '{}';
  v_supps bigint[] := '{}';
  v_batches bigint[] := '{}';
  v_rate numeric;
  v_box int;
  v_amt numeric;
  v_cur text;
  v_box_usd numeric := 0;
  v_idx int := 0;
  v_n int := 0;
  v_boxes integer[] := '{}';
  v_mixed jsonb := null;
  v_first_box int := null;
  v_local text := p_sale->>'localId';
  v_inv text := p_sale->>'inv';
  v_pay text := left(p_sale->>'payType', 20);
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'sale');
  if v_r is not null then return v_r; end if;

  if coalesce(p_filial, '') = '' then raise exception 'LEDGER: filial majburiy' using errcode = 'P0001'; end if;
  if coalesce(v_local, '') !~ '^[0-9A-Za-z_.:-]{1,64}$' then raise exception 'LEDGER: savdo ID noto''g''ri' using errcode = 'P0001'; end if;
  if coalesce(v_inv, '') = '' or length(v_inv) > 40 then raise exception 'LEDGER: chek raqami noto''g''ri' using errcode = 'P0001'; end if;
  if jsonb_typeof(p_sale->'items') <> 'array' or jsonb_array_length(p_sale->'items') < 1 or jsonb_array_length(p_sale->'items') > 500 then
    raise exception 'LEDGER: savat bo''sh yoki juda katta' using errcode = 'P0001';
  end if;
  v_disc := public._fw_num(p_sale->>'discPct');
  v_paid := public._fw_num(p_sale->>'paidUsd');
  if v_disc < 0 or v_disc > 100 or v_paid < 0 or v_paid > 1000000000 then
    raise exception 'LEDGER: chegirma yoki to''lov noto''g''ri' using errcode = 'P0001';
  end if;
  v_cust := case when coalesce(p_sale->>'custId', '') ~ '^[0-9]{1,18}$' and (p_sale->>'custId')::numeric > 0 then (p_sale->>'custId')::bigint end;
  if exists (select 1 from public.sales where filial = p_filial and local_id = v_local) then
    raise exception 'LEDGER: savdo ID takrorlandi' using errcode = 'P0001';
  end if;

  for v_item in select * from jsonb_array_elements(p_sale->'items') loop
    v_qty := public._fw_num(v_item->>'qty'); v_sell := public._fw_num(v_item->>'sellUsd'); v_icost := public._fw_num(v_item->>'costUsd');
    if coalesce(v_item->>'pid', '') !~ '^[0-9]{1,18}$' or v_qty <= 0 or v_qty > 1000000 or v_sell < 0 or v_sell > 1000000000 or v_icost < 0 or v_icost > 1000000000 then
      raise exception 'LEDGER: savatdagi qator noto''g''ri (pid=%)', v_item->>'pid' using errcode = 'P0001';
    end if;
    v_subtotal := v_subtotal + v_qty * v_sell;
    v_items := v_items || jsonb_build_object('pid', (v_item->>'pid')::bigint, 'sku', left(v_item->>'sku', 80), 'name', left(v_item->>'name', 300),
      'qty', v_qty, 'sell_usd', v_sell, 'cost_usd', v_icost, 'line_usd', v_qty * v_sell,
      'direct_supply', coalesce(v_item->>'directSupply', 'false') = 'true',
      'supp_id', case when coalesce(v_item->>'suppId', '') ~ '^[0-9]{1,18}$' then (v_item->>'suppId')::bigint end);
  end loop;
  v_total := v_subtotal * (1 - v_disc / 100);

  -- Kassaga tushum (aralash to'lov): qaysi kassalarga — bazadagi haqiqiy tushum asosida (void uchun)
  if p_box_payments is not null and jsonb_typeof(p_box_payments) = 'array' then
    if jsonb_array_length(p_box_payments) > 10 then raise exception 'LEDGER: kassa to''lovlari juda ko''p' using errcode = 'P0001'; end if;
    select jsonb_agg(jsonb_build_object('boxId', (e->>'box_id')::int, 'amount', public._fw_num(e->>'amount_native')))
      into v_mixed from jsonb_array_elements(p_box_payments) e
     where coalesce(e->>'box_id', '') ~ '^[0-9]{1,9}$' and public._fw_num(e->>'amount_native') > 0;
    v_first_box := (v_mixed->0->>'boxId')::int;
  end if;

  insert into public.sales (filial, inv, cust_id, subtotal_usd, disc_pct, total_usd, cost_usd, profit_usd, paid_usd, debt_usd, items,
                            local_id, pay_type, box_id, mixed_rows, cust_name, disc_usd, sale_date, status, staff_id, staff_name, is_transfer)
  values (p_filial, v_inv, v_cust, v_subtotal, v_disc, v_total, 0, 0, least(v_paid, v_total), 0, v_items,
          v_local, v_pay,
          case when v_pay = 'mixed' then null
               else coalesce(v_first_box, case when coalesce(p_sale->>'boxId', '') ~ '^[0-9]{1,9}$' then (p_sale->>'boxId')::int end) end,
          case when v_pay = 'mixed' then v_mixed end,
          left(p_sale->>'custName', 200), v_subtotal - v_total,
          case when coalesce(p_sale->>'saleDate', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (p_sale->>'saleDate')::date else current_date end,
          'done', p_staff_id, left(p_staff_name, 200), coalesce(p_sale->>'isTransfer', 'false') = 'true')
  returning * into v_sale;

  -- Ombor (FIFO) — mahsulot ID tartibida qulflanadi (parallel savdolarda deadlock bo'lmasligi uchun)
  for v_item in select e from jsonb_array_elements(v_items) e order by (e->>'pid')::bigint loop
    v_n := v_n + 1;
    v_pid := (v_item->>'pid')::bigint; v_qty := (v_item->>'qty')::numeric;
    if (v_item->>'direct_supply')::boolean then
      v_cost := v_cost + v_qty * (v_item->>'cost_usd')::numeric;
      if v_item->>'supp_id' is not null then
        v_side := v_side || jsonb_build_object('supp', (v_item->>'supp_id')::bigint, 'usd', v_qty * (v_item->>'cost_usd')::numeric, 'kind', 'sale_direct');
      end if;
    else
      v_fifo := public._stock_fifo_out(p_filial, v_pid, v_qty, 'sale', 'sale:' || v_sale.id || ':' || v_n, 'sale:' || v_sale.id,
                                       'sale', v_inv, 'Savdo ' || v_inv, p_staff_id, p_staff_name);
      v_cost := v_cost + (v_fifo->>'cost')::numeric;
      v_side := v_side || (v_fifo->'side');
      v_bd := v_bd + (v_fifo->>'bd')::numeric;
      v_batches := v_batches || array(select (a->>'batchId')::bigint from jsonb_array_elements(v_fifo->'allocs') a);
    end if;
  end loop;
  v_supps := public._fw_apply_side_debts(p_filial, v_side, v_bd, 'sale:' || v_sale.id, 'sale:' || v_sale.id, 'sale', v_inv, p_staff_id, p_staff_name);

  v_profit := v_total - v_cost;
  v_debt := greatest(0, v_total - v_paid);
  v_change := greatest(0, v_paid - v_total);

  -- Mijoz qarzi (so'm) — serverdagi kurs bo'yicha
  if v_cust is not null and v_debt > 0 then
    v_rate := public._fw_rate();
    perform public._cust_debt_move(p_filial, v_cust, round(v_debt * v_rate, 2), 'strict', 'sale', 'sale:' || v_sale.id, 'sale:' || v_sale.id,
                                   'sale', v_inv, 'Savdo ' || v_inv, p_staff_id, p_staff_name);
    v_custs := v_custs || v_cust;
  end if;

  -- Kassaga tushum — kassa jurnali orqali; savdo summasidan (2% / 1$ chegarasi bilan) oshmaydi
  if p_box_payments is not null and jsonb_typeof(p_box_payments) = 'array' then
    for v_bp in select * from jsonb_array_elements(p_box_payments) loop
      v_idx := v_idx + 1;
      continue when coalesce(v_bp->>'box_id', '') !~ '^[0-9]{1,9}$';
      v_box := (v_bp->>'box_id')::int;
      v_amt := public._fw_num(v_bp->>'amount_native');
      continue when v_amt <= 0;
      select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = v_box;
      v_cur := coalesce(v_cur, case when v_bp->>'currency' in ('USD','UZS') then v_bp->>'currency' end);
      if v_cur is null then
        raise exception 'CASHBOX: kassa valyutasi noma''lum (kassa %)', v_box using errcode = 'P0001';
      end if;
      if v_cur = 'USD' then
        v_box_usd := v_box_usd + v_amt;
      else
        v_rate := coalesce(v_rate, public._fw_rate());
        v_box_usd := v_box_usd + v_amt / v_rate;
      end if;
      perform public._cb_move(p_filial, v_box, v_cur, 'in', v_amt, 'sale', 'sale:' || v_sale.id || ':' || v_idx, 'sale:' || v_sale.id,
                              left(v_bp->>'box_name', 200), 'sale', v_inv, 'Savdo ' || v_inv, p_staff_id, p_staff_name);
      v_boxes := v_boxes || v_box;
    end loop;
    if v_box_usd > v_total + greatest(1, v_total * 0.02) then
      raise exception 'CASHBOX: kassaga tushum (% $) savdo summasidan (% $) oshib ketdi — qaytimni ayiring', round(v_box_usd, 2), round(v_total, 2) using errcode = 'P0001';
    end if;
  end if;

  update public.sales set cost_usd = v_cost, profit_usd = v_profit, debt_usd = v_debt where id = v_sale.id returning * into v_sale;

  return public._ledger_op_finish(p_filial, p_op_key, 'sale', jsonb_build_object(
    'ok', true, 'saleId', v_sale.id, 'localId', v_local, 'inv', v_inv,
    'subtotalUsd', v_subtotal, 'totalUsd', v_total, 'costUsd', v_cost,
    'profitUsd', v_profit, 'debtUsd', v_debt, 'changeUsd', v_change,
    'sale', public._fw_sale_json(v_sale),
    'balances', public._cb_balances_map(p_filial, v_boxes)),
    v_custs, v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- Eski chaqiruv (v2) — endi v3 orqali (kod yangilanmagan bo'lsa ham ombor/qarz serverda to'g'ri)
CREATE OR REPLACE FUNCTION public.sale_checkout_atomic_v2(p_filial text, p_items jsonb, p_disc_pct numeric, p_paid_usd numeric, p_cust_id bigint, p_box_payments jsonb, p_inv text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = ''
AS $function$
declare
  v_key text := 'v2:' || replace(gen_random_uuid()::text, '-', '');
begin
  return public.sale_checkout_atomic_v3(p_filial, v_key, jsonb_build_object(
    'localId', v_key, 'inv', p_inv, 'custId', p_cust_id, 'discPct', coalesce(p_disc_pct, 0), 'paidUsd', p_paid_usd,
    'payType', case when jsonb_typeof(p_box_payments) = 'array' and jsonb_array_length(p_box_payments) > 1 then 'mixed' end,
    'items', (select coalesce(jsonb_agg(jsonb_build_object('pid', e->'pid', 'sku', e->'sku', 'name', e->'name', 'qty', e->'qty',
               'sellUsd', e->'sell_usd', 'costUsd', e->'cost_usd', 'directSupply', e->'direct_supply', 'suppId', e->'supp_id')), '[]'::jsonb)
               from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e)),
    p_box_payments, null, null);
end;
$function$;

-- ── 6. Qaytarish — SERVERDAGI savdo yozuvidan hisoblanadi ───────────────
-- Avvalgi biznes qoidasi saqlangan: qaytarish summasi savdodagi skidka bilan; avval mijozning shu savdo
-- bo'yicha qarzi kamayadi, faqat qolgani naqd qaytariladi; ombordan sotilgan tovar tannarxi bilan YANGI
-- partiya bo'lib qaytadi; ta'minotchidan to'g'ridan-to'g'ri sotilgan bo'lsa — ta'minotchi qarzi kamayadi.
create or replace function public.sale_return_atomic(
  p_filial text, p_op_key text, p_sale_local_id text, p_pid bigint, p_qty numeric, p_batch_local_id text, p_meta jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  s public.sales;
  v_item jsonb;
  v_idx bigint;
  v_iqty numeric;
  v_sell numeric;
  v_cost numeric;
  v_direct boolean;
  v_supp bigint;
  v_gross numeric;
  v_ratio numeric;
  v_rev numeric;
  v_profit numeric;
  v_debt_part numeric;
  v_cash_part numeric;
  v_rate numeric;
  v_box int;
  v_cur text;
  v_amt numeric := 0;
  v_cash jsonb := null;
  v_b public.batches;
  v_custs bigint[] := '{}';
  v_supps bigint[] := '{}';
  v_batches bigint[] := '{}';
  v_key text;
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'sale_return');
  if v_r is not null then return v_r; end if;
  v_key := 'ret:' || p_op_key;

  select * into s from public.sales where filial = p_filial and local_id = p_sale_local_id for update;
  if not found then
    raise exception 'LEDGER: savdo serverda topilmadi — sahifani yangilang' using errcode = 'P0001';
  end if;
  if s.voided_at is not null then raise exception 'LEDGER: savdo o''chirilgan' using errcode = 'P0001'; end if;
  select e, o into v_item, v_idx from jsonb_array_elements(s.items) with ordinality as t(e, o)
   where public._fw_num(e->>'pid') = p_pid order by o limit 1;
  if v_item is null then raise exception 'LEDGER: savdoda bu mahsulot yo''q' using errcode = 'P0001'; end if;
  v_iqty := public._fw_num(v_item->>'qty');
  if p_qty is null or p_qty <= 0 or p_qty > v_iqty + 0.000001 then
    raise exception 'LEDGER: qaytarish miqdori noto''g''ri (savdoda qolgan: %)', v_iqty using errcode = 'P0001';
  end if;
  v_sell := public._fw_num(v_item->>'sell_usd');
  v_cost := public._fw_num(v_item->>'cost_usd');
  v_direct := coalesce(v_item->>'direct_supply', 'false') = 'true';
  v_supp := case when coalesce(v_item->>'supp_id', '') ~ '^[0-9]{1,18}$' then (v_item->>'supp_id')::bigint end;

  v_gross := p_qty * v_sell;
  v_ratio := case when s.subtotal_usd > 0 then least(1, greatest(0, coalesce(s.total_usd, 0) / s.subtotal_usd)) else 1 end;
  v_rev := v_gross * v_ratio;
  v_profit := v_rev - p_qty * v_cost;
  v_debt_part := least(v_rev, greatest(0, coalesce(s.debt_usd, 0)));
  v_cash_part := least(greatest(0, v_rev - v_debt_part), greatest(0, coalesce(s.paid_usd, 0)));

  if v_direct then
    if v_supp is not null then
      perform public._supp_debt_move(p_filial, v_supp, -(p_qty * v_cost), 0, 'clamp', 'sale_return', v_key, v_key, 'sale', s.inv,
                                     'Qaytarish: ' || s.inv, p_staff_id, p_staff_name);
      v_supps := v_supps || v_supp;
    end if;
  else
    v_b := public._batch_insert(p_filial, p_batch_local_id, p_pid, p_qty, v_cost, 'active',
             coalesce(p_meta, '{}'::jsonb) || jsonb_build_object('origin', left('Qaytarish — ' || s.inv || ' (' || coalesce(s.cust_name, 'Anonim') || ')', 300)),
             'sale_return', v_key, v_key, 'sale', s.inv, p_staff_id, p_staff_name);
    v_batches := v_batches || v_b.id;
  end if;

  if v_debt_part > 0 and s.cust_id is not null then
    v_rate := public._fw_rate();
    perform public._cust_debt_move(p_filial, s.cust_id, -round(v_debt_part * v_rate, 2), 'clamp', 'sale_return', v_key, v_key, 'sale', s.inv,
                                   'Qaytarish: ' || s.inv, p_staff_id, p_staff_name);
    v_custs := v_custs || s.cust_id;
  end if;

  v_box := coalesce(s.box_id, case when jsonb_typeof(s.mixed_rows) = 'array' and coalesce(s.mixed_rows->0->>'boxId', '') ~ '^[0-9]{1,9}$'
                                   then (s.mixed_rows->0->>'boxId')::int end);
  if v_box is not null and v_cash_part > 0.000001 then
    select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = v_box;
    if v_cur is null then raise exception 'CASHBOX: qaytarish kassasi topilmadi (kassa %)', v_box using errcode = 'P0001'; end if;
    v_amt := case when v_cur = 'USD' then round(v_cash_part, 2) else round(v_cash_part * public._fw_rate(), 2) end;
    if v_amt > 0 then
      v_cash := public.cashbox_apply_ops(p_filial, v_key, 'sale_fix', jsonb_build_array(jsonb_build_object('box', v_box, 'currency', v_cur,
                  'dir', 'out', 'amount', v_amt, 'note', left('Qaytarish: ' || s.inv || ' — ' || p_qty || ' dona', 500), 'ref_type', 'sale', 'ref_id', s.inv)),
                  p_staff_id, p_staff_name);
    end if;
  end if;

  update public.sales
     set items = jsonb_set(items, array[(v_idx - 1)::text], v_item || jsonb_build_object('qty', v_iqty - p_qty, 'line_usd', (v_iqty - p_qty) * v_sell)),
         subtotal_usd = greatest(0, subtotal_usd - v_gross),
         total_usd = greatest(0, total_usd - v_rev),
         paid_usd = greatest(0, paid_usd - v_cash_part),
         debt_usd = case when v_debt_part > 0 then greatest(0, debt_usd - v_debt_part) else debt_usd end
   where id = s.id
   returning * into s;

  return public._ledger_op_finish(p_filial, p_op_key, 'sale_return', jsonb_build_object(
    'ok', true, 'saleLocalId', s.local_id, 'inv', s.inv, 'pid', p_pid, 'qty', p_qty, 'wasDirectSupply', v_direct,
    'returnGross', v_gross, 'returnRevenue', v_rev, 'returnProfit', v_profit, 'debtPart', v_debt_part, 'cashPart', v_cash_part,
    'refundBox', v_box, 'refundAmount', v_amt, 'batchLocalId', case when v_b.id is not null then v_b.local_id end,
    'sale', public._fw_sale_json(s), 'balances', coalesce(v_cash->'balances', '{}'::jsonb)),
    v_custs, v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 7. Savdoni o'chirish (void) — ombor, kassa, mijoz qarzi teskari ────
-- Avvalgi qoida: savdodagi har bir mahsulot (asl tannarxda) YANGI partiya bo'lib omborga qaytadi,
-- to'langan summa kassadan (aralash to'lovda — har bir kassadan) qaytariladi, mijoz qarzi kamayadi.
create or replace function public.sale_void_atomic(
  p_filial text, p_op_key text, p_sale_local_id text, p_batch_ids jsonb, p_meta jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  s public.sales;
  v_item jsonb;
  v_o bigint;
  v_qty numeric;
  v_b public.batches;
  v_rate numeric;
  v_cur text;
  v_ops jsonb := '[]'::jsonb;
  v_row jsonb;
  v_cash jsonb := null;
  v_custs bigint[] := '{}';
  v_batches bigint[] := '{}';
  v_restocked jsonb := '[]'::jsonb;
  v_key text;
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'sale_void');
  if v_r is not null then return v_r; end if;
  v_key := 'void:' || p_op_key;
  select * into s from public.sales where filial = p_filial and local_id = p_sale_local_id for update;
  if not found then raise exception 'LEDGER: savdo serverda topilmadi — sahifani yangilang' using errcode = 'P0001'; end if;
  if s.voided_at is not null then raise exception 'LEDGER: savdo allaqachon o''chirilgan' using errcode = 'P0001'; end if;

  for v_item, v_o in select e, o from jsonb_array_elements(s.items) with ordinality as t(e, o) order by o loop
    v_qty := public._fw_num(v_item->>'qty');
    continue when v_qty <= 0;
    v_b := public._batch_insert(p_filial, p_batch_ids->>(v_o - 1)::int, public._fw_num(v_item->>'pid')::bigint, v_qty,
             public._fw_num(v_item->>'cost_usd'), 'active',
             coalesce(p_meta, '{}'::jsonb) || jsonb_build_object('origin', left('O''chirilgan savdo — ' || s.inv, 300)),
             'sale_void', v_key || ':' || v_o, v_key, 'sale', s.inv, p_staff_id, p_staff_name);
    v_batches := v_batches || v_b.id;
    v_restocked := v_restocked || jsonb_build_object('localId', v_b.local_id, 'pid', v_b.pid, 'qty', v_b.qty);
  end loop;

  if s.cust_id is not null and coalesce(s.debt_usd, 0) > 0 then
    v_rate := public._fw_rate();
    perform public._cust_debt_move(p_filial, s.cust_id, -round(s.debt_usd * v_rate, 2), 'clamp', 'sale_void', v_key, v_key, 'sale', s.inv,
                                   'Savdo o''chirildi: ' || s.inv, p_staff_id, p_staff_name);
    v_custs := v_custs || s.cust_id;
  end if;

  if s.box_id is not null and coalesce(s.paid_usd, 0) > 0 then
    select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = s.box_id;
    if v_cur is not null then
      v_ops := v_ops || jsonb_build_object('box', s.box_id, 'currency', v_cur, 'dir', 'out',
        'amount', case when v_cur = 'USD' then round(s.paid_usd, 2) else round(s.paid_usd * public._fw_rate(), 2) end,
        'note', left('Savdo o''chirildi — ' || s.inv, 500), 'ref_type', 'sale', 'ref_id', s.inv);
    end if;
  end if;
  if s.pay_type = 'mixed' and jsonb_typeof(s.mixed_rows) = 'array' then
    for v_row in select * from jsonb_array_elements(s.mixed_rows) loop
      continue when coalesce(v_row->>'boxId', '') !~ '^[0-9]{1,9}$' or public._fw_num(v_row->>'amount') <= 0;
      select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = (v_row->>'boxId')::int;
      continue when v_cur is null;
      v_ops := v_ops || jsonb_build_object('box', (v_row->>'boxId')::int, 'currency', v_cur, 'dir', 'out', 'amount', round(public._fw_num(v_row->>'amount'), 2),
        'note', left('Savdo o''chirildi (aralash) — ' || s.inv, 500), 'ref_type', 'sale', 'ref_id', s.inv);
    end loop;
  end if;
  v_ops := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(v_ops) e where public._fw_num(e->>'amount') > 0);
  if jsonb_array_length(v_ops) > 0 then
    v_cash := public.cashbox_apply_ops(p_filial, v_key, 'sale_fix', v_ops, p_staff_id, p_staff_name);
  end if;

  update public.sales set status = 'voided', voided_at = now() where id = s.id returning * into s;

  return public._ledger_op_finish(p_filial, p_op_key, 'sale_void', jsonb_build_object(
    'ok', true, 'saleLocalId', s.local_id, 'inv', s.inv, 'restocked', v_restocked,
    'sale', public._fw_sale_json(s), 'balances', coalesce(v_cash->'balances', '{}'::jsonb)),
    v_custs, '{}', v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 8. Savdoni tahrirlash — uch rejim (avvalgi uchta UI oqimiga mos) ───
-- 'replace' (admin, "Savdoni tahrirlash"): eski mahsulotlar YANGI partiya bo'lib qaytadi, yangilari FIFO'dan;
--            to'lov turi "qarz" bo'lsa hammasi qarz, aks holda hammasi to'langan; kassa: eski to'lov chiqim, yangisi kirim.
-- 'delta'   (admin, "Yopilgan savdo"): faqat farq (ko'p — FIFO, kam — yangi partiya); to'langan summa o'zgarmaydi,
--            qarz = max(0, yangi jami − to'langan).
-- 'price'   (sotuvchi): faqat narx; farq qarzga (qarz savdosi) yoki kassaga (naqd/karta).
create or replace function public.sale_edit_atomic(
  p_filial text, p_op_key text, p_sale_local_id text, p_mode text, p_payload jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  s public.sales;
  v_old jsonb;
  v_new jsonb := '[]'::jsonb;
  v_e jsonb;
  v_it jsonb;
  v_o bigint;
  v_i int;
  v_n int := 0;
  v_qty numeric;
  v_nq numeric;
  v_sell numeric;
  v_subtotal numeric := 0;
  v_total numeric;
  v_cost numeric := 0;
  v_disc numeric;
  v_disc_usd numeric;
  v_paid numeric;
  v_debt numeric;
  v_delta numeric;
  v_rate numeric;
  v_cur text;
  v_amt numeric;
  v_fifo jsonb;
  v_side jsonb := '[]'::jsonb;
  v_bd numeric := 0;
  v_ops jsonb := '[]'::jsonb;
  v_cash jsonb := null;
  v_b public.batches;
  v_seen int[] := '{}';
  v_out jsonb := '[]'::jsonb;        -- FIFO kerak bo'lgan qatorlar: [{pid, qty}]
  v_custs bigint[] := '{}';
  v_supps bigint[] := '{}';
  v_batches bigint[] := '{}';
  v_key text;
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'sale_edit');
  if v_r is not null then return v_r; end if;
  v_key := 'sedit:' || p_op_key;
  if p_mode is null or p_mode not in ('replace','delta','price') then
    raise exception 'LEDGER: tahrir rejimi noto''g''ri' using errcode = 'P0001';
  end if;
  select * into s from public.sales where filial = p_filial and local_id = p_sale_local_id for update;
  if not found then raise exception 'LEDGER: savdo serverda topilmadi — sahifani yangilang' using errcode = 'P0001'; end if;
  if s.voided_at is not null then raise exception 'LEDGER: savdo o''chirilgan' using errcode = 'P0001'; end if;
  v_old := s.items;

  if p_mode = 'replace' then
    if jsonb_typeof(p_payload->'items') <> 'array' then raise exception 'LEDGER: mahsulotlar ro''yxati yo''q' using errcode = 'P0001'; end if;
    for v_e in select * from jsonb_array_elements(p_payload->'items') loop
      v_i := public._fw_num(v_e->>'idx')::int;
      if v_i < 0 or v_i >= jsonb_array_length(v_old) or v_i = any(v_seen) then
        raise exception 'LEDGER: tahrirdagi qator noto''g''ri' using errcode = 'P0001';
      end if;
      v_seen := v_seen || v_i;
      v_qty := public._fw_num(v_e->>'qty'); v_sell := public._fw_num(v_e->>'sellUsd');
      continue when v_qty <= 0;
      if v_qty > 1000000 or v_sell < 0 or v_sell > 1000000000 then raise exception 'LEDGER: miqdor yoki narx noto''g''ri' using errcode = 'P0001'; end if;
      v_it := (v_old->v_i) || jsonb_build_object('qty', v_qty, 'sell_usd', v_sell, 'line_usd', v_qty * v_sell);
      v_new := v_new || v_it;
      v_subtotal := v_subtotal + v_qty * v_sell;
      v_cost := v_cost + v_qty * public._fw_num(v_it->>'cost_usd');
      v_out := v_out || jsonb_build_object('pid', public._fw_num(v_it->>'pid')::bigint, 'qty', v_qty);
    end loop;
    if jsonb_array_length(v_new) = 0 then raise exception 'LEDGER: kamida bitta mahsulot qolishi kerak' using errcode = 'P0001'; end if;
    v_total := v_subtotal;
    v_paid := case when s.pay_type = 'debt' then 0 else v_total end;
    v_debt := case when s.pay_type = 'debt' then v_total else 0 end;
    -- eski mahsulotlar omborga (yangi partiya sifatida)
    for v_it, v_o in select e, o from jsonb_array_elements(v_old) with ordinality as t(e, o) order by o loop
      v_qty := public._fw_num(v_it->>'qty');
      continue when v_qty <= 0;
      v_b := public._batch_insert(p_filial, p_payload->'restockIds'->>(v_o - 1)::int, public._fw_num(v_it->>'pid')::bigint, v_qty,
               public._fw_num(v_it->>'cost_usd'), 'active',
               coalesce(p_payload->'meta', '{}'::jsonb) || jsonb_build_object('origin', left('Tahrirlash — ' || s.inv, 300)),
               'sale_edit', v_key || ':r:' || v_o, v_key, 'sale', s.inv, p_staff_id, p_staff_name);
      v_batches := v_batches || v_b.id;
    end loop;
  elsif p_mode = 'delta' then
    v_disc := public._fw_num(p_payload->>'discPct');
    if v_disc < 0 or v_disc > 100 then raise exception 'LEDGER: chegirma noto''g''ri' using errcode = 'P0001'; end if;
    for v_it, v_o in select e, o from jsonb_array_elements(v_old) with ordinality as t(e, o) order by o loop
      v_e := (select e2 from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb)) e2 where public._fw_num(e2->>'idx') = v_o - 1 limit 1);
      v_qty := public._fw_num(v_it->>'qty');
      v_nq := case when v_e is not null and v_e ? 'qty' and v_e->>'qty' is not null then public._fw_num(v_e->>'qty') else v_qty end;
      v_sell := case when v_e is not null and v_e ? 'sellUsd' and v_e->>'sellUsd' is not null then public._fw_num(v_e->>'sellUsd') else public._fw_num(v_it->>'sell_usd') end;
      if v_nq < 0 or v_nq > 1000000 or v_sell < 0 or v_sell > 1000000000 then raise exception 'LEDGER: miqdor yoki narx noto''g''ri' using errcode = 'P0001'; end if;
      if v_nq > v_qty then
        v_out := v_out || jsonb_build_object('pid', public._fw_num(v_it->>'pid')::bigint, 'qty', v_nq - v_qty);
      elsif v_nq < v_qty then
        v_b := public._batch_insert(p_filial, p_payload->'restockIds'->>(v_o - 1)::int, public._fw_num(v_it->>'pid')::bigint, v_qty - v_nq,
                 public._fw_num(v_it->>'cost_usd'), 'active',
                 coalesce(p_payload->'meta', '{}'::jsonb) || jsonb_build_object('origin', 'Savdo tahrirlandi (qaytdi)'),
                 'sale_edit', v_key || ':r:' || v_o, v_key, 'sale', s.inv, p_staff_id, p_staff_name);
        v_batches := v_batches || v_b.id;
      end if;
      v_it := v_it || jsonb_build_object('qty', v_nq, 'sell_usd', v_sell, 'line_usd', v_nq * v_sell);
      v_new := v_new || v_it;
      v_subtotal := v_subtotal + v_nq * v_sell;
      v_cost := v_cost + v_nq * public._fw_num(v_it->>'cost_usd');
    end loop;
    v_disc_usd := v_subtotal * v_disc / 100;
    v_total := v_subtotal - v_disc_usd;
    v_paid := coalesce(s.paid_usd, 0);
    v_debt := greatest(0, v_total - v_paid);
  else
    if jsonb_typeof(p_payload->'prices') <> 'array' or jsonb_array_length(p_payload->'prices') <> jsonb_array_length(v_old) then
      raise exception 'LEDGER: narxlar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    for v_it, v_o in select e, o from jsonb_array_elements(v_old) with ordinality as t(e, o) order by o loop
      v_sell := public._fw_num(p_payload->'prices'->>(v_o - 1)::int);
      if v_sell < 0 or v_sell > 1000000000 then raise exception 'LEDGER: narx noto''g''ri' using errcode = 'P0001'; end if;
      v_qty := public._fw_num(v_it->>'qty');
      v_new := v_new || (v_it || jsonb_build_object('sell_usd', v_sell, 'line_usd', v_qty * v_sell));
      v_subtotal := v_subtotal + v_qty * v_sell;
    end loop;
    v_disc_usd := v_subtotal * coalesce(s.disc_pct, 0) / 100;
    v_total := v_subtotal - v_disc_usd;
    v_delta := v_total - coalesce(s.total_usd, 0);
  end if;

  -- Ombordan chiqarish (FIFO) — mahsulot ID tartibida
  for v_e in select e from jsonb_array_elements(v_out) e order by (e->>'pid')::bigint loop
    v_n := v_n + 1;
    v_fifo := public._stock_fifo_out(p_filial, (v_e->>'pid')::bigint, (v_e->>'qty')::numeric, 'sale_edit', v_key || ':f:' || v_n, v_key,
                                     'sale', s.inv, 'Savdo tahrirlandi: ' || s.inv, p_staff_id, p_staff_name);
    v_side := v_side || (v_fifo->'side');
    v_bd := v_bd + (v_fifo->>'bd')::numeric;
    v_batches := v_batches || array(select (a->>'batchId')::bigint from jsonb_array_elements(v_fifo->'allocs') a);
  end loop;
  v_supps := public._fw_apply_side_debts(p_filial, v_side, v_bd, v_key, v_key, 'sale', s.inv, p_staff_id, p_staff_name);

  -- Mijoz qarzi
  if s.cust_id is not null then
    if p_mode = 'replace' then
      if coalesce(s.debt_usd, 0) > 0 or v_debt > 0 then v_rate := public._fw_rate(); end if;
      if coalesce(s.debt_usd, 0) > 0 then
        perform public._cust_debt_move(p_filial, s.cust_id, -round(s.debt_usd * v_rate, 2), 'clamp', 'sale_edit', v_key || ':o', v_key, 'sale', s.inv,
                                       'Tahrirlash (eski): ' || s.inv, p_staff_id, p_staff_name);
        v_custs := v_custs || s.cust_id;
      end if;
      if v_debt > 0 then
        perform public._cust_debt_move(p_filial, s.cust_id, round(v_debt * v_rate, 2), 'strict', 'sale_edit', v_key || ':n', v_key, 'sale', s.inv,
                                       'Tahrirlash (yangi): ' || s.inv, p_staff_id, p_staff_name);
        v_custs := v_custs || s.cust_id;
      end if;
    elsif p_mode = 'delta' then
      v_rate := public._fw_rate();
      if round(v_debt * v_rate, 2) - round(coalesce(s.debt_usd, 0) * v_rate, 2) <> 0 then
        perform public._cust_debt_move(p_filial, s.cust_id, round(v_debt * v_rate, 2) - round(coalesce(s.debt_usd, 0) * v_rate, 2), 'clamp', 'sale_edit',
                                       v_key, v_key, 'sale', s.inv, 'Savdo tahrirlandi: ' || s.inv, p_staff_id, p_staff_name);
        v_custs := v_custs || s.cust_id;
      end if;
    elsif s.pay_type = 'debt' and v_delta <> 0 then
      v_rate := public._fw_rate();
      perform public._cust_debt_move(p_filial, s.cust_id, round(v_delta * v_rate, 2), 'clamp', 'sale_edit', v_key, v_key, 'sale', s.inv,
                                     'Savdo tahrirlandi: ' || s.inv, p_staff_id, p_staff_name);
      v_custs := v_custs || s.cust_id;
    end if;
  end if;

  -- Kassa
  if s.box_id is not null and p_mode in ('replace','price') then
    select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = s.box_id;
    if v_cur is not null then
      if p_mode = 'replace' then
        if coalesce(s.paid_usd, 0) > 0 then
          v_ops := v_ops || jsonb_build_object('box', s.box_id, 'currency', v_cur, 'dir', 'out',
            'amount', case when v_cur = 'USD' then round(s.paid_usd, 2) else round(s.paid_usd * public._fw_rate(), 2) end,
            'note', left('Tahrirlash (eski) — ' || s.inv, 500), 'ref_type', 'sale', 'ref_id', s.inv);
        end if;
        if v_paid > 0 then
          v_ops := v_ops || jsonb_build_object('box', s.box_id, 'currency', v_cur, 'dir', 'in',
            'amount', case when v_cur = 'USD' then round(v_paid, 2) else round(v_paid * public._fw_rate(), 2) end,
            'note', left('Tahrirlash (yangi) — ' || s.inv, 500), 'ref_type', 'sale', 'ref_id', s.inv);
        end if;
      elsif s.pay_type is distinct from 'debt' then
        v_amt := case when v_cur = 'USD' then v_delta else v_delta * public._fw_rate() end;
        if abs(v_amt) >= 0.005 then
          v_ops := v_ops || jsonb_build_object('box', s.box_id, 'currency', v_cur, 'dir', case when v_amt >= 0 then 'in' else 'out' end,
            'amount', round(abs(v_amt), 2), 'note', left('Savdo tahrirlandi: ' || s.inv, 500), 'ref_type', 'sale', 'ref_id', s.inv);
        end if;
      end if;
      v_ops := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(v_ops) e where public._fw_num(e->>'amount') > 0);
      if jsonb_array_length(v_ops) > 0 then
        v_cash := public.cashbox_apply_ops(p_filial, v_key, 'sale_fix', v_ops, p_staff_id, p_staff_name);
      end if;
    end if;
  end if;

  if p_mode = 'replace' then
    update public.sales set items = v_new, subtotal_usd = v_total, total_usd = v_total, paid_usd = v_paid, debt_usd = v_debt,
           profit_usd = v_total - v_cost, edited_at = now()
     where id = s.id returning * into s;
  elsif p_mode = 'delta' then
    update public.sales set items = v_new, subtotal_usd = v_subtotal, disc_pct = v_disc, disc_usd = v_disc_usd, total_usd = v_total,
           debt_usd = v_debt, profit_usd = v_total - v_cost, edited_at = now()
     where id = s.id returning * into s;
  else
    update public.sales set items = v_new, subtotal_usd = v_subtotal, disc_usd = v_disc_usd, total_usd = v_total,
           debt_usd = case when pay_type = 'debt' then greatest(0, debt_usd + v_delta) else debt_usd end,
           paid_usd = case when pay_type = 'debt' then paid_usd else greatest(0, paid_usd + v_delta) end,
           edited_at = now()
     where id = s.id returning * into s;
  end if;

  return public._ledger_op_finish(p_filial, p_op_key, 'sale_edit', jsonb_build_object(
    'ok', true, 'mode', p_mode, 'saleLocalId', s.local_id, 'inv', s.inv,
    'restocked', coalesce((select jsonb_agg(jsonb_build_object('localId', b.local_id, 'pid', b.pid, 'qty', b.qty, 'costUsd', b.cost_usd) order by b.id)
                           from public.batches b where b.id = any(v_batches) and b.local_id = any(array(select jsonb_array_elements_text(coalesce(
                             case when jsonb_typeof(p_payload->'restockIds') = 'array' then p_payload->'restockIds' else '[]'::jsonb end, '[]'::jsonb))))), '[]'::jsonb),
    'sale', public._fw_sale_json(s), 'balances', coalesce(v_cash->'balances', '{}'::jsonb)),
    v_custs, v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 9. To'lov + kassa — qarz qatori QULFLANADI, qarzdan ortiq to'lov bazada rad etiladi ──
-- Yangi nom (_v2): 24/25-migratsiya qayta ishga tushirilsa ham (eski funksiyalarni qayta yaratadi)
-- yangi kod ishlatadigan funksiya o'zgarmaydi. Eski nom (cash_payment_atomic) — shu funksiyaga yo'naltiriladi
-- (eski kod bilan ham qarz bazada tekshiriladi). Ikki qurilmadan bir vaqtda 2×400 000 (qarz 600 000):
-- ikkinchisi qulfda kutadi, keyin HAQIQIY qoldiq (200 000) bo'yicha rad etiladi va uning kassa harakati ham bekor bo'ladi.
create or replace function public.cash_payment_atomic_v2(
  p_filial text, p_group_key text, p_kind text, p_ops jsonb, p_record_type text, p_record jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_res jsonb;
  v_amt numeric;
  v_debt numeric;
  v_dealer record;
  v_party bigint;
  v_extra jsonb := '{}'::jsonb;
begin
  if p_record_type is null or p_record_type not in ('customer_debt_payment','supplier_payment','dealer_payment','home_withdrawal') then
    raise exception 'CASHBOX: to''lov turi noto''g''ri' using errcode = 'P0001';
  end if;
  if p_record is null or jsonb_typeof(p_record) <> 'object' then
    raise exception 'CASHBOX: to''lov ma''lumoti yo''q' using errcode = 'P0001';
  end if;

  -- Qulflash tartibi: qarz qatori → kassa (sotuv/qaytarish bilan bir xil)
  if p_record_type = 'dealer_payment' then
    v_amt := round((p_record->>'amount_usd')::numeric, 2);
    select id, debt_usd, total_paid_usd, filial into v_dealer from public.dealers where id = (p_record->>'dealer_id')::bigint for update;
    if not found then raise exception 'CASHBOX: diller topilmadi' using errcode = 'P0001'; end if;
    if coalesce(v_dealer.filial, 'baza') <> p_filial then raise exception 'CASHBOX: diller boshqa filialga tegishli' using errcode = 'P0001'; end if;
  elsif p_record_type = 'customer_debt_payment' then
    v_party := case when coalesce(p_record->>'customer_local_id', '') ~ '^[0-9]{1,18}$' then (p_record->>'customer_local_id')::bigint end;
    v_amt := round(public._fw_num(p_record->>'amount_uzs'), 2);
    if v_party is null or v_amt <= 0 then raise exception 'CASHBOX: mijoz yoki summa noto''g''ri' using errcode = 'P0001'; end if;
    perform set_config('fw.debt_move', '1', true);
    insert into public.customer_balances (filial, customer_local_id, debt, currency) values (p_filial, v_party, 0, 'UZS')
      on conflict (filial, customer_local_id) do nothing;
    perform set_config('fw.debt_move', '', true);
    perform 1 from public.customer_balances where filial = p_filial and customer_local_id = v_party for update;
  elsif p_record_type = 'supplier_payment' then
    v_party := case when coalesce(p_record->>'supplier_local_id', '') ~ '^[0-9]{1,18}$' then (p_record->>'supplier_local_id')::bigint end;
    v_amt := round(public._fw_num(p_record->>'amount_usd'), 4);
    if v_party is null or v_amt <= 0 then raise exception 'CASHBOX: ta''minotchi yoki summa noto''g''ri' using errcode = 'P0001'; end if;
    perform set_config('fw.debt_move', '1', true);
    insert into public.supplier_balances (filial, supplier_local_id, debt, currency) values (p_filial, v_party, 0, 'USD')
      on conflict (filial, supplier_local_id) do nothing;
    perform set_config('fw.debt_move', '', true);
    perform 1 from public.supplier_balances where filial = p_filial and supplier_local_id = v_party for update;
  end if;

  v_res := public.cashbox_apply_ops(p_filial, p_group_key, p_kind, p_ops, p_staff_id, p_staff_name);
  if coalesce((v_res->>'replay')::boolean, false) then
    if p_record_type = 'dealer_payment' then
      v_extra := jsonb_build_object('dealerDebtUsd', v_dealer.debt_usd, 'dealerTotalPaidUsd', v_dealer.total_paid_usd);
    elsif p_record_type = 'customer_debt_payment' then
      v_extra := jsonb_build_object('customerDebt', (select debt from public.customer_balances where filial = p_filial and customer_local_id = v_party));
    elsif p_record_type = 'supplier_payment' then
      v_extra := (select jsonb_build_object('supplierDebt', debt, 'supplierPaid', total_paid) from public.supplier_balances where filial = p_filial and supplier_local_id = v_party);
    end if;
    return v_res || coalesce(v_extra, '{}'::jsonb);   -- yozuv birinchi chaqiruvda (shu tranzaksiyada) qo'shilgan
  end if;

  if p_record_type = 'customer_debt_payment' then
    v_debt := public._cust_debt_move(p_filial, v_party, -v_amt, 'strict', 'payment', 'pay:' || p_group_key, p_group_key,
                                     'customer_debt_payment', null, left(p_record->>'customer_name', 200), p_staff_id, p_staff_name);
    insert into public.customer_debt_payments (filial, customer_local_id, customer_name, amount_uzs, box_local_id, staff_id, staff_name, idem_key)
    values (p_filial, v_party, left(p_record->>'customer_name', 200), v_amt, (p_record->>'box_local_id')::integer, p_staff_id, left(p_staff_name, 200), p_group_key);
    v_extra := jsonb_build_object('customerDebt', v_debt);
  elsif p_record_type = 'supplier_payment' then
    v_debt := public._supp_debt_move(p_filial, v_party, -v_amt, v_amt, 'strict', 'payment', 'pay:' || p_group_key, p_group_key,
                                     'supplier_payment', null, left(p_record->>'supplier_name', 200), p_staff_id, p_staff_name);
    insert into public.supplier_payments (filial, supplier_local_id, supplier_name, amount_usd, box_local_id, staff_id, staff_name, idem_key)
    values (p_filial, v_party, left(p_record->>'supplier_name', 200), v_amt, (p_record->>'box_local_id')::integer, p_staff_id, left(p_staff_name, 200), p_group_key);
    v_extra := (select jsonb_build_object('supplierDebt', debt, 'supplierPaid', total_paid) from public.supplier_balances where filial = p_filial and supplier_local_id = v_party);
  elsif p_record_type = 'home_withdrawal' then
    insert into public.home_withdrawals (filial, entries, note, staff_id, staff_name, idem_key)
    values (p_filial, coalesce(p_record->'entries', '[]'::jsonb), left(p_record->>'note', 500), p_staff_id, left(p_staff_name, 200), p_group_key);
  else
    v_debt := coalesce(v_dealer.debt_usd, 0);
    if v_amt is null or v_amt <= 0 or v_amt > v_debt + 0.01 then
      raise exception 'CASHBOX: to''lov (% $) diller qarzidan (% $) oshib ketdi', v_amt, v_debt using errcode = 'P0001';
    end if;
    insert into public.dealer_payments (dealer_id, amount_usd, note, idem_key)
    values (v_dealer.id, v_amt, left(p_record->>'note', 300), p_group_key);
    update public.dealers set debt_usd = greatest(round(debt_usd - v_amt, 2), 0), total_paid_usd = coalesce(total_paid_usd, 0) + v_amt
     where id = v_dealer.id
     returning debt_usd, total_paid_usd into v_dealer.debt_usd, v_dealer.total_paid_usd;
    v_extra := jsonb_build_object('dealerDebtUsd', v_dealer.debt_usd, 'dealerTotalPaidUsd', v_dealer.total_paid_usd);
  end if;
  return v_res || coalesce(v_extra, '{}'::jsonb);
end;
$$;

create or replace function public.cash_payment_atomic(
  p_filial text, p_group_key text, p_kind text, p_ops jsonb, p_record_type text, p_record jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language sql
 set search_path = ''
as $$
  select public.cash_payment_atomic_v2(p_filial, p_group_key, p_kind, p_ops, p_record_type, p_record, p_staff_id, p_staff_name);
$$;

-- ── 10. Ombor va qarz amallari (savdodan tashqari) — bitta tranzaksiyada, idempotent ──
-- p_kind:
--   cust_set       {customerId, debt, reason:'opening'|'adjust', name}       — qo'lda qarz (boshlang'ich / tahrir)
--   supp_set       {supplierId, debt, reason, name}
--   batches_create {reason:'kirim'|'import'|'opening'|'dealer_return', batches:[{localId,pid,qty,costUsd,status,meta}],
--                   supplier:{id, consignment, goodsUsd, givenUsd}, kirimRef, fkRef}
--   batch_edit     {edits:[{localId, qty, costUsd}]}  — ta'minotchi qarzi farqi SERVERDA (yangi − eski qiymat)
--   batch_delete   {localIds:[...]}                     — holati 'deleted' (tarix saqlanadi)
--   batch_arrive   {localIds:[...], costAdds:{localId: $/dona}} — yo'ldagi partiya omborga keldi
--   revision       {facts:[{pid, fact}], apply, surplusIds:{pid: localId}, meta} — tizim qoldig'i SERVERDA
--   stock_out      {reason:'transfer'|'dealer', items:[{pid, qty}], target, targetBatches:[{pid, localId, costUsd, bno}],
--                   transferSale:{localId, inv, custName, items:[{pid, sku, name, qty, sellUsd}]}}
create or replace function public.stock_debt_op(
  p_filial text, p_op_key text, p_kind text, p_payload jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  p jsonb := coalesce(p_payload, '{}'::jsonb);
  v_key text := 'op:' || p_op_key;
  v_id bigint;
  v_val numeric;
  v_e jsonb;
  v_b public.batches;
  v_n int := 0;
  v_custs bigint[] := '{}';
  v_supps bigint[] := '{}';
  v_batches bigint[] := '{}';
  v_res jsonb := '{}'::jsonb;
  v_reason text;
  v_kind text;
  v_value numeric := 0;
  v_goods numeric;
  v_given numeric;
  v_paid_rec numeric;
  v_rate numeric;
  v_ref text;
  v_fkref text;
  v_status text;
  v_consign boolean;
  v_supp bigint;
  v_side jsonb := '[]'::jsonb;
  v_bd numeric := 0;
  v_fifo jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_items jsonb := '[]'::jsonb;
  v_sys numeric;
  v_cost numeric;
  v_fact numeric;
  v_diff numeric;
  v_target text;
  v_tsale jsonb;
  v_ttotal numeric := 0;
  v_tcost numeric := 0;
  r record;
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, p_kind);
  if v_r is not null then return v_r; end if;
  if coalesce(p_filial, '') = '' then raise exception 'LEDGER: filial majburiy' using errcode = 'P0001'; end if;

  if p_kind = 'cust_set' or p_kind = 'supp_set' then
    v_id := case when coalesce(p->>(case when p_kind = 'cust_set' then 'customerId' else 'supplierId' end), '') ~ '^[0-9]{1,18}$'
                 then (p->>(case when p_kind = 'cust_set' then 'customerId' else 'supplierId' end))::bigint end;
    v_val := public._fw_num(p->>'debt');
    if v_id is null or v_id <= 0 or v_val < 0 or v_val > 1000000000000 then
      raise exception 'LEDGER: qarz qiymati noto''g''ri' using errcode = 'P0001';
    end if;
    v_kind := case when p->>'reason' = 'opening' then 'opening' else 'adjust' end;
    if p_kind = 'cust_set' then
      v_val := public._cust_debt_move(p_filial, v_id, v_val, 'set', v_kind, v_key, v_key, 'customer', v_id::text,
                                      left('Qo''lda: ' || coalesce(p->>'name', ''), 500), p_staff_id, p_staff_name);
      v_custs := array[v_id];
    else
      v_val := public._supp_debt_move(p_filial, v_id, v_val, 0, 'set', v_kind, v_key, v_key, 'supplier', v_id::text,
                                      left('Qo''lda: ' || coalesce(p->>'name', ''), 500), p_staff_id, p_staff_name);
      v_supps := array[v_id];
    end if;
    v_res := jsonb_build_object('debt', v_val);

  elsif p_kind = 'batches_create' then
    v_reason := p->>'reason';
    if v_reason is null or v_reason not in ('kirim','import','opening','dealer_return') then
      raise exception 'LEDGER: kirim turi noto''g''ri' using errcode = 'P0001';
    end if;
    if jsonb_typeof(p->'batches') <> 'array' or jsonb_array_length(p->'batches') < 1 or jsonb_array_length(p->'batches') > 500 then
      raise exception 'LEDGER: partiyalar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    v_ref := left(p->>'kirimRef', 64);
    v_fkref := left(p->>'fkRef', 64);
    v_supp := case when coalesce(p->'supplier'->>'id', '') ~ '^[0-9]{1,18}$' then (p->'supplier'->>'id')::bigint end;
    v_consign := v_supp is not null and coalesce(p->'supplier'->>'consignment', 'false') = 'true';
    v_kind := case v_reason when 'opening' then 'opening_stock' else v_reason end;
    for v_e in select * from jsonb_array_elements(p->'batches') loop
      v_n := v_n + 1;
      v_status := case when v_reason = 'kirim' and v_e->>'status' = 'transit' then 'transit' else 'active' end;
      v_b := public._batch_insert(p_filial, v_e->>'localId', public._fw_num(v_e->>'pid')::bigint, public._fw_num(v_e->>'qty'),
               public._fw_num(v_e->>'costUsd'), v_status,
               coalesce(v_e->'meta', '{}'::jsonb) || jsonb_build_object('kirimRef', v_ref, 'fkRef', v_fkref,
                 'suppId', case when v_reason in ('kirim','import') then v_supp end, 'consignment', v_consign and v_reason in ('kirim','import'),
                 'fromBranch', null),
               v_kind, v_key || ':' || v_n, v_key, v_reason, coalesce(v_ref, p_op_key), p_staff_id, p_staff_name);
      v_batches := v_batches || v_b.id;
      v_value := v_value + v_b.qty * v_b.cost_usd;
    end loop;
    if v_reason in ('kirim','import') and v_supp is not null and not v_consign then
      v_goods := public._fw_num(p->'supplier'->>'goodsUsd');
      v_given := case when v_reason = 'kirim' then public._fw_num(p->'supplier'->>'givenUsd') else 0 end;
      if v_goods < 0 or v_given < 0 then raise exception 'LEDGER: kirim summasi noto''g''ri' using errcode = 'P0001'; end if;
      if v_goods > v_value + greatest(0.01, v_value * 0.001) then
        raise exception 'LEDGER: tovar qiymati (% $) partiyalar qiymatidan (% $) oshib ketdi', round(v_goods, 2), round(v_value, 2) using errcode = 'P0001';
      end if;
      if v_given > 0 then
        -- "To'langan" summa — kassa / Firma kassa jurnalidagi HAQIQIY to'lovdan oshmasin
        if exists (select 1 from public.batches b where b.filial = p_filial and b.kirim_ref = v_ref and b.id <> all(v_batches)) then
          raise exception 'LEDGER: bu to''lov boshqa kirimga bog''langan' using errcode = 'P0001';
        end if;
        v_rate := nullif(public._fw_num((select data->'settings'->>'usdUzs' from public.app_data where id = 'main')), 0);
        select coalesce(sum(case when l.currency = 'USD' then l.amount when v_rate is not null then l.amount / v_rate else 0 end), 0) into v_paid_rec
          from public.cashbox_ledger l where l.filial = p_filial and l.ref_type = 'kirim' and l.ref_id = v_ref and l.direction = 'out';
        v_paid_rec := v_paid_rec + coalesce((select sum(case when f.currency = 'USD' then f.amount when v_rate is not null then f.amount / v_rate else 0 end)
          from public.firma_kassa_ledger f where f.op_type = 'kirim_payment' and f.ref_id = v_fkref and v_fkref is not null and f.reversed_by is null), 0);
        if v_given > v_paid_rec + 0.01 then
          raise exception 'LEDGER: to''langan summa (% $) kassa yozuvlaridan (% $) oshib ketdi', round(v_given, 2), round(v_paid_rec, 2) using errcode = 'P0001';
        end if;
      end if;
      perform public._supp_debt_move(p_filial, v_supp, v_goods - v_given, v_given, case when v_reason = 'kirim' then 'clamp' else 'strict' end,
                                     v_reason, v_key || ':s', v_key, v_reason, coalesce(v_ref, p_op_key), 'Kirim', p_staff_id, p_staff_name);
      v_supps := array[v_supp];
    end if;
    v_res := jsonb_build_object('created', (select jsonb_agg(jsonb_build_object('localId', local_id, 'pid', pid, 'qty', qty, 'costUsd', cost_usd, 'status', status) order by id)
                                            from public.batches where id = any(v_batches)));

  elsif p_kind = 'batch_edit' then
    if jsonb_typeof(p->'edits') <> 'array' or jsonb_array_length(p->'edits') < 1 or jsonb_array_length(p->'edits') > 500 then
      raise exception 'LEDGER: tahrir ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    perform 1 from public.batches where filial = p_filial and local_id in (select e->>'localId' from jsonb_array_elements(p->'edits') e)
      order by id for update;
    for r in select b.*, public._fw_num(e->>'qty') as nq, public._fw_num(e->>'costUsd') as nc
               from jsonb_array_elements(p->'edits') e join public.batches b on b.filial = p_filial and b.local_id = e->>'localId'
              order by b.id loop
      if r.status = 'deleted' then raise exception 'LEDGER: partiya o''chirilgan' using errcode = 'P0001'; end if;
      if r.nq < r.sold - 0.000001 then
        raise exception 'LEDGER: miqdor sotilgandan (%) kam bo''la olmaydi', r.sold using errcode = 'P0001';
      end if;
      if r.nc < 0 or r.nc > 10000000 or r.nq > 10000000 then raise exception 'LEDGER: miqdor yoki tannarx noto''g''ri' using errcode = 'P0001'; end if;
      continue when r.nq = r.qty and r.nc = r.cost_usd;
      v_n := v_n + 1;
      if r.supp_id is not null then
        v_side := v_side || jsonb_build_object('supp', r.supp_id, 'usd', r.nq * r.nc - r.qty * r.cost_usd);
      end if;
      v_b := public._stock_move(r.id, r.nq - r.qty, 0, 'edit', v_key || ':' || r.id, v_key, 'batch', r.local_id, 'Partiya tahrirlandi',
                                p_staff_id, p_staff_name, null, r.nc);
      v_batches := v_batches || r.id;
    end loop;
    if jsonb_array_length((select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(p->'edits') e)) <>
       (select count(*) from jsonb_array_elements(p->'edits') e join public.batches b on b.filial = p_filial and b.local_id = e->>'localId') then
      raise exception 'LEDGER: partiya topilmadi' using errcode = 'P0001';
    end if;
    for r in select (e->>'supp')::bigint as supp, sum(public._fw_num(e->>'usd')) as usd from jsonb_array_elements(v_side) e group by 1 order by 1 loop
      continue when r.usd = 0;
      perform public._supp_debt_move(p_filial, r.supp, r.usd, 0, 'clamp', 'batch_edit', v_key || ':s:' || r.supp, v_key, 'batch', null,
                                     'Partiya tahriri', p_staff_id, p_staff_name);
      v_supps := v_supps || r.supp;
    end loop;
    v_res := jsonb_build_object('changed', v_n);

  elsif p_kind = 'batch_delete' or p_kind = 'batch_arrive' then
    if jsonb_typeof(p->'localIds') <> 'array' or jsonb_array_length(p->'localIds') < 1 or jsonb_array_length(p->'localIds') > 500 then
      raise exception 'LEDGER: partiyalar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    if (select count(*) from public.batches b where b.filial = p_filial and b.local_id in (select jsonb_array_elements_text(p->'localIds')))
       <> (select count(distinct x) from jsonb_array_elements_text(p->'localIds') x) then
      raise exception 'LEDGER: partiya topilmadi' using errcode = 'P0001';
    end if;
    for r in select b.* from public.batches b where b.filial = p_filial and b.local_id in (select jsonb_array_elements_text(p->'localIds')) order by b.id for update loop
      if p_kind = 'batch_delete' then
        v_b := public._stock_move(r.id, 0, 0, 'delete', v_key || ':' || r.id, v_key, 'batch', r.local_id, 'Partiya o''chirildi',
                                  p_staff_id, p_staff_name, 'deleted', null);
      else
        if r.status <> 'transit' then raise exception 'LEDGER: partiya yo''lda emas (%)', r.local_id using errcode = 'P0001'; end if;
        v_val := public._fw_num(p->'costAdds'->>r.local_id);
        if v_val < 0 or v_val > 1000000 then raise exception 'LEDGER: bojxona ulushi noto''g''ri' using errcode = 'P0001'; end if;
        v_b := public._stock_move(r.id, 0, 0, 'arrive', v_key || ':' || r.id, v_key, 'batch', r.local_id, 'Partiya keldi',
                                  p_staff_id, p_staff_name, 'active', r.cost_usd + v_val);
      end if;
      v_batches := v_batches || r.id;
    end loop;

  elsif p_kind = 'revision' then
    if jsonb_typeof(p->'facts') <> 'array' or jsonb_array_length(p->'facts') < 1 or jsonb_array_length(p->'facts') > 5000 then
      raise exception 'LEDGER: reviziya ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    for v_e in select e from jsonb_array_elements(p->'facts') e order by public._fw_num(e->>'pid') loop
      v_id := public._fw_num(v_e->>'pid')::bigint;
      v_fact := public._fw_num(v_e->>'fact');
      if v_id <= 0 or v_fact < 0 or v_fact > 10000000 then raise exception 'LEDGER: reviziya qatori noto''g''ri' using errcode = 'P0001'; end if;
      perform 1 from public.batches where filial = p_filial and pid = v_id and status = 'active' order by batch_date asc nulls last, id asc for update;
      select coalesce(sum(qty - sold), 0) into v_sys from public.batches where filial = p_filial and pid = v_id and status = 'active';
      select cost_usd into v_cost from public.batches where filial = p_filial and pid = v_id and status = 'active' and qty > sold
        order by batch_date asc nulls last, id asc limit 1;
      v_cost := coalesce(v_cost, 0);
      v_diff := v_fact - v_sys;
      if coalesce(p->>'apply', 'false') = 'true' and v_diff <> 0 then
        v_n := v_n + 1;
        if v_diff > 0 then
          v_b := public._batch_insert(p_filial, p->'surplusIds'->>v_id::text, v_id, v_diff, v_cost, 'active',
                   coalesce(p->'meta', '{}'::jsonb) || jsonb_build_object('origin', 'Revizya ortig''i'),
                   'revision', v_key || ':' || v_n, v_key, 'revision', p_op_key, p_staff_id, p_staff_name);
          v_batches := v_batches || v_b.id;
        else
          v_fifo := public._stock_fifo_out(p_filial, v_id, -v_diff, 'revision', v_key || ':' || v_n, v_key, 'revision', p_op_key,
                                           'Reviziya kamomadi', p_staff_id, p_staff_name);
          v_side := v_side || (v_fifo->'side');
          v_bd := v_bd + (v_fifo->>'bd')::numeric;
          v_batches := v_batches || array(select (a->>'batchId')::bigint from jsonb_array_elements(v_fifo->'allocs') a);
        end if;
      end if;
      v_rows := v_rows || jsonb_build_object('pid', v_id, 'sysQty', v_sys, 'factQty', v_fact, 'diff', v_diff, 'diffUsd', v_diff * v_cost, 'cost', v_cost);
    end loop;
    v_supps := public._fw_apply_side_debts(p_filial, v_side, v_bd, v_key, v_key, 'revision', p_op_key, p_staff_id, p_staff_name);
    v_res := jsonb_build_object('rows', v_rows);

  elsif p_kind = 'stock_out' then
    v_reason := p->>'reason';
    if v_reason is null or v_reason not in ('transfer','dealer') then raise exception 'LEDGER: amal turi noto''g''ri' using errcode = 'P0001'; end if;
    if jsonb_typeof(p->'items') <> 'array' or jsonb_array_length(p->'items') < 1 or jsonb_array_length(p->'items') > 500 then
      raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    if v_reason = 'transfer' then
      v_target := p->>'target';
      if p_filial <> 'baza' or coalesce(v_target, '') !~ '^[a-z0-9_]{1,40}$' or v_target = 'baza' then
        raise exception 'LEDGER: ko''chirish faqat Bazadan filialga' using errcode = 'P0001';
      end if;
    end if;
    for v_e in select e from jsonb_array_elements(p->'items') e order by public._fw_num(e->>'pid') loop
      v_n := v_n + 1;
      v_id := public._fw_num(v_e->>'pid')::bigint;
      v_fifo := public._stock_fifo_out(p_filial, v_id, public._fw_num(v_e->>'qty'), case when v_reason = 'transfer' then 'transfer_out' else 'dealer_out' end,
                                       v_key || ':' || v_n, v_key, v_reason, coalesce(v_target, p->>'dealerId', p_op_key),
                                       case when v_reason = 'transfer' then 'Filialga: ' || v_target else 'Dillerga' end, p_staff_id, p_staff_name);
      v_side := v_side || (v_fifo->'side');
      v_bd := v_bd + (v_fifo->>'bd')::numeric;
      v_batches := v_batches || array(select (a->>'batchId')::bigint from jsonb_array_elements(v_fifo->'allocs') a);
      v_items := v_items || jsonb_build_object('pid', v_id, 'qty', public._fw_num(v_e->>'qty'), 'firstCost', (v_fifo->>'firstCost')::numeric, 'cost', (v_fifo->>'cost')::numeric);
    end loop;
    v_supps := public._fw_apply_side_debts(p_filial, v_side, v_bd, v_key, v_key, v_reason, p_op_key, p_staff_id, p_staff_name);
    if v_reason = 'transfer' then
      if jsonb_typeof(p->'targetBatches') <> 'array' then raise exception 'LEDGER: filial partiyalari yo''q' using errcode = 'P0001'; end if;
      for v_e in select * from jsonb_array_elements(p->'targetBatches') loop
        if public._fw_num(v_e->>'qty') <> coalesce((select sum(public._fw_num(i->>'qty')) from jsonb_array_elements(p->'items') i
                                                    where public._fw_num(i->>'pid') = public._fw_num(v_e->>'pid')), -1) then
          raise exception 'LEDGER: filial partiyasi miqdori Bazadan chiqqan miqdorga teng emas' using errcode = 'P0001';
        end if;
        v_b := public._batch_insert(v_target, v_e->>'localId', public._fw_num(v_e->>'pid')::bigint, public._fw_num(v_e->>'qty'),
                 public._fw_num(v_e->>'costUsd'), 'active',
                 jsonb_build_object('origin', 'Bazadan (filial)', 'fromBranch', 'baza', 'bno', left(v_e->>'bno', 20), 'date', v_e->>'date'),
                 'transfer_in', v_key || ':t:' || (v_e->>'localId'), v_key, 'transfer', p_op_key, p_staff_id, p_staff_name);
        v_batches := v_batches || v_b.id;
      end loop;
      v_tsale := p->'transferSale';
      if v_tsale is not null and jsonb_typeof(v_tsale) = 'object' then
        select coalesce(sum(public._fw_num(i->>'qty') * public._fw_num(i->>'sellUsd')), 0) into v_ttotal from jsonb_array_elements(v_tsale->'items') i;
        select coalesce(sum(public._fw_num(x->>'qty') * public._fw_num(x->>'firstCost')), 0) into v_tcost from jsonb_array_elements(v_items) x;
        insert into public.sales (filial, inv, cust_id, subtotal_usd, disc_pct, total_usd, cost_usd, profit_usd, paid_usd, debt_usd, items,
                                  local_id, pay_type, cust_name, disc_usd, sale_date, status, staff_id, staff_name, is_transfer)
        values (p_filial, left(v_tsale->>'inv', 40), null, v_ttotal, 0, v_ttotal, v_tcost, v_ttotal - v_tcost, 0, v_ttotal,
                (select coalesce(jsonb_agg(jsonb_build_object('pid', public._fw_num(i->>'pid')::bigint, 'sku', left(i->>'sku', 80), 'name', left(i->>'name', 300),
                   'qty', public._fw_num(i->>'qty'), 'sell_usd', public._fw_num(i->>'sellUsd'),
                   'cost_usd', coalesce((select (x->>'firstCost')::numeric from jsonb_array_elements(v_items) x where (x->>'pid')::bigint = public._fw_num(i->>'pid')::bigint limit 1), 0),
                   'line_usd', public._fw_num(i->>'qty') * public._fw_num(i->>'sellUsd'), 'direct_supply', false, 'supp_id', null)), '[]'::jsonb)
                   from jsonb_array_elements(v_tsale->'items') i),
                v_tsale->>'localId', 'debt', left(v_tsale->>'custName', 200), 0, current_date, 'done', p_staff_id, left(p_staff_name, 200), true);
      end if;
    end if;
    v_res := jsonb_build_object('items', v_items);
  else
    raise exception 'LEDGER: noma''lum amal' using errcode = 'P0001';
  end if;

  return public._ledger_op_finish(p_filial, p_op_key, p_kind, jsonb_build_object('ok', true, 'kind', p_kind) || v_res,
                                  v_custs, v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 11. app_data (asosiy qator) — branchDebt faqat serverda o'zgaradi ───
-- Brauzer saqlashi (app-data-save) branchDebt'ni qayta yozmaydi: shu zahotdagi bazadagi qiymat qoladi
-- (yozish paytida qator qulflanadi — sotuvdagi oshirish yo'qolmaydi).
create or replace function public.app_data_save_main(p_data jsonb)
 returns void
 language plpgsql
 set search_path = ''
as $$
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'LEDGER: ma''lumot noto''g''ri' using errcode = 'P0001';
  end if;
  update public.app_data
     set data = (p_data - 'branchDebt') || jsonb_build_object('branchDebt', coalesce(data->'branchDebt', '{}'::jsonb)), updated_at = now()
   where id = 'main';
  if not found then
    insert into public.app_data (id, data, updated_at) values ('main', p_data, now());
  end if;
end;
$$;

-- v23.10: ilovada yo'q (eskirgan soya) partiyalar FIFO'dan chiqarilishidan OLDIN asl qatori to'liq saqlanadi.
-- Hech narsa o'chirilmaydi. Egasi qaror qiladi: tovar haqiqatan yo'q — 'confirmed_absent';
-- bor bo'lsa — ilovada «Boshlang'ich qoldiq» orqali kiritiladi ('reentered'). SQL orqali 'active' qilinmasin:
-- ilova faqat o'z ro'yxatidagi partiyalarni ko'rsatadi (server va ilova ajralib qoladi).
create table if not exists public.m27_stale_batches_archive (
  batch_id bigint primary key,
  filial text not null,
  local_id text,
  pid bigint,
  qty numeric,
  sold numeric,
  cost_usd numeric,
  original jsonb not null,
  archived_at timestamp with time zone not null default now(),
  decision text not null default 'pending',
  decided_at timestamp with time zone,
  decided_by text,
  note text,
  constraint m27_stale_batches_archive_decision_chk check (decision in ('pending','confirmed_absent','reentered'))
);
alter table public.m27_stale_batches_archive enable row level security;
revoke all on public.m27_stale_batches_archive from public, anon, authenticated;
grant select, update on public.m27_stale_batches_archive to service_role;

-- ── 12. Boshlang'ich qiymatlar — hozirgi JSON'dan BIR MARTA ('opening') ─────
-- Manba: app_data_branches.data (ilova shu yerdan yuklaydi), yo'q bo'lsa app_data.branchStore[filial].
-- Qayta ishga tushirilsa: jurnalida yozuvi bor mijoz/ta'minotchi/partiyaga TEGILMAYDI.
do $$
declare
  r record;
  v_old numeric;
  v_val numeric;
  v_paid numeric;
  v_b public.batches;
  v_qty numeric;
  v_sold numeric;
  v_status text;
  v_inv text;
  v_items jsonb;
  v_filials text[];
begin
  perform set_config('fw.debt_move', '1', true);
  perform set_config('fw.stock_move', '1', true);

  select coalesce(array_agg(distinct f), '{}') into v_filials from (
    select b.branch_key as f from public.app_data_branches b where jsonb_typeof(b.data) = 'object'
    union select s.key from public.app_data a, jsonb_each(coalesce(a.data->'branchStore', '{}'::jsonb)) s
     where a.id = 'main' and jsonb_typeof(s.value) = 'object') q;

  -- 12a. Mijozlar (so'm)
  for r in
    with src as (
      select b.branch_key as filial, b.data from public.app_data_branches b where jsonb_typeof(b.data) = 'object'
      union all
      select s.key, s.value from public.app_data a, jsonb_each(coalesce(a.data->'branchStore', '{}'::jsonb)) s
       where a.id = 'main' and jsonb_typeof(s.value) = 'object'
         and not exists (select 1 from public.app_data_branches b2 where b2.branch_key = s.key and jsonb_typeof(b2.data) = 'object'))
    select src.filial, (c->>'id')::bigint as id, c->>'debt' as debt from src,
           jsonb_array_elements(case when jsonb_typeof(src.data->'customers') = 'array' then src.data->'customers' else '[]'::jsonb end) c
     where jsonb_typeof(c) = 'object' and coalesce(c->>'id', '') ~ '^[0-9]{1,18}$' and (c->>'id')::numeric > 0
  loop
    continue when exists (select 1 from public.customer_debt_ledger l where l.filial = r.filial and l.customer_local_id = r.id);
    v_val := round(public._fw_num(r.debt), 2);
    select debt into v_old from public.customer_balances where filial = r.filial and customer_local_id = r.id;
    insert into public.customer_balances (filial, customer_local_id, debt, currency, updated_at) values (r.filial, r.id, v_val, 'UZS', now())
      on conflict (filial, customer_local_id) do update set debt = excluded.debt, currency = 'UZS', updated_at = now();
    insert into public.customer_debt_ledger (filial, customer_local_id, delta, balance_after, op_kind, op_key, note)
      values (r.filial, r.id, v_val, v_val, 'opening', 'opening:' || r.id,
              'Boshlang''ich qoldiq (27-migratsiya, ilovadagi qiymat)' || case when v_old is not null then ' · avvalgi soya qiymati: ' || v_old else '' end)
      on conflict (filial, op_key) do nothing;
  end loop;
  -- JSON'da yo'q (eskirgan soya) mijoz qatorlari — 0 ga tenglashtiriladi, eski qiymat izohda
  for r in select cb.filial, cb.customer_local_id as id, cb.debt from public.customer_balances cb
            where not exists (select 1 from public.customer_debt_ledger l where l.filial = cb.filial and l.customer_local_id = cb.customer_local_id) loop
    update public.customer_balances set debt = 0, currency = 'UZS', updated_at = now() where filial = r.filial and customer_local_id = r.id;
    insert into public.customer_debt_ledger (filial, customer_local_id, delta, balance_after, op_kind, op_key, note)
      values (r.filial, r.id, 0, 0, 'opening', 'opening:' || r.id, 'Ilovada yo''q mijoz — soya qiymati bekor qilindi: ' || r.debt)
      on conflict (filial, op_key) do nothing;
  end loop;

  -- 12b. Ta'minotchilar ($)
  for r in
    with src as (
      select b.branch_key as filial, b.data from public.app_data_branches b where jsonb_typeof(b.data) = 'object'
      union all
      select s.key, s.value from public.app_data a, jsonb_each(coalesce(a.data->'branchStore', '{}'::jsonb)) s
       where a.id = 'main' and jsonb_typeof(s.value) = 'object'
         and not exists (select 1 from public.app_data_branches b2 where b2.branch_key = s.key and jsonb_typeof(b2.data) = 'object'))
    select src.filial, (c->>'id')::bigint as id, c->>'debt' as debt, c->>'paid' as paid from src,
           jsonb_array_elements(case when jsonb_typeof(src.data->'suppliers') = 'array' then src.data->'suppliers' else '[]'::jsonb end) c
     where jsonb_typeof(c) = 'object' and coalesce(c->>'id', '') ~ '^[0-9]{1,18}$' and (c->>'id')::numeric > 0
  loop
    continue when exists (select 1 from public.supplier_debt_ledger l where l.filial = r.filial and l.supplier_local_id = r.id);
    v_val := round(public._fw_num(r.debt), 4);
    v_paid := greatest(round(public._fw_num(r.paid), 4), 0);
    select debt into v_old from public.supplier_balances where filial = r.filial and supplier_local_id = r.id;
    insert into public.supplier_balances (filial, supplier_local_id, debt, currency, total_paid, updated_at) values (r.filial, r.id, v_val, 'USD', v_paid, now())
      on conflict (filial, supplier_local_id) do update set debt = excluded.debt, currency = 'USD', total_paid = excluded.total_paid, updated_at = now();
    insert into public.supplier_debt_ledger (filial, supplier_local_id, delta, paid_delta, balance_after, op_kind, op_key, note)
      values (r.filial, r.id, v_val, v_paid, v_val, 'opening', 'opening:' || r.id,
              'Boshlang''ich qoldiq (27-migratsiya, ilovadagi qiymat)' || case when v_old is not null then ' · avvalgi soya qiymati: ' || v_old else '' end)
      on conflict (filial, op_key) do nothing;
  end loop;
  for r in select sb.filial, sb.supplier_local_id as id, sb.debt from public.supplier_balances sb
            where not exists (select 1 from public.supplier_debt_ledger l where l.filial = sb.filial and l.supplier_local_id = sb.supplier_local_id) loop
    update public.supplier_balances set debt = 0, currency = 'USD', updated_at = now() where filial = r.filial and supplier_local_id = r.id;
    insert into public.supplier_debt_ledger (filial, supplier_local_id, delta, paid_delta, balance_after, op_kind, op_key, note)
      values (r.filial, r.id, 0, 0, 0, 'opening', 'opening:' || r.id, 'Ilovada yo''q ta''minotchi — soya qiymati bekor qilindi: ' || r.debt)
      on conflict (filial, op_key) do nothing;
  end loop;

  -- 12c. Partiyalar (ombor qoldig'i)
  for r in
    with src as (
      select b.branch_key as filial, b.data from public.app_data_branches b where jsonb_typeof(b.data) = 'object'
      union all
      select s.key, s.value from public.app_data a, jsonb_each(coalesce(a.data->'branchStore', '{}'::jsonb)) s
       where a.id = 'main' and jsonb_typeof(s.value) = 'object'
         and not exists (select 1 from public.app_data_branches b2 where b2.branch_key = s.key and jsonb_typeof(b2.data) = 'object'))
    select src.filial, bt from src,
           jsonb_array_elements(case when jsonb_typeof(src.data->'batches') = 'array' then src.data->'batches' else '[]'::jsonb end) bt
     where jsonb_typeof(bt) = 'object' and coalesce(bt->>'id', '') ~ '^[0-9A-Za-z_.:-]{1,64}$'
       and coalesce(bt->>'pid', '') ~ '^[0-9]{1,18}$'
  loop
    select * into v_b from public.batches where filial = r.filial and local_id = r.bt->>'id';
    continue when found and exists (select 1 from public.stock_ledger l where l.batch_id = v_b.id);
    v_qty := greatest(public._fw_num(r.bt->>'qty'), 0);
    v_sold := least(greatest(public._fw_num(r.bt->>'sold'), 0), v_qty);
    v_status := case when r.bt->>'status' = 'transit' then 'transit' when v_qty - v_sold <= 0.000001 then 'empty' else 'active' end;
    if v_b.id is not null then
      update public.batches set pid = (r.bt->>'pid')::bigint, qty = v_qty, sold = v_sold, status = v_status,
             cost_usd = greatest(public._fw_num(r.bt->>'costUsd'), 0), bank_fee_usd = greatest(public._fw_num(r.bt->>'bankFeeUsd'), 0),
             supp_id = case when coalesce(r.bt->>'suppId', '') ~ '^[0-9]{1,18}$' then (r.bt->>'suppId')::bigint end,
             consignment = coalesce(r.bt->>'consignment', 'false') = 'true',
             from_branch = case when r.bt->>'fromBranch' ~ '^[a-z0-9_]{1,40}$' then r.bt->>'fromBranch' end,
             batch_date = case when coalesce(r.bt->>'date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (r.bt->>'date')::date else batch_date end,
             bno = left(r.bt->>'bno', 20), origin = left(r.bt->>'origin', 300), kirim_ref = left(r.bt->>'kirimRef', 64), fk_ref = left(r.bt->>'fkRef', 64),
             updated_at = now()
       where id = v_b.id returning * into v_b;
    else
      insert into public.batches (local_id, filial, pid, bno, origin, cur, qty, sold, cost_usd, bank_fee_usd, supp_id, consignment,
                                  rate_usd_uzs, rate_usd_cny, batch_date, status, performed_by, from_branch, kirim_ref, fk_ref)
      values (r.bt->>'id', r.filial, (r.bt->>'pid')::bigint, left(r.bt->>'bno', 20), left(r.bt->>'origin', 300),
              case when r.bt->>'cur' in ('USD','UZS','CNY','KRW') then r.bt->>'cur' else 'USD' end,
              v_qty, v_sold, greatest(public._fw_num(r.bt->>'costUsd'), 0), greatest(public._fw_num(r.bt->>'bankFeeUsd'), 0),
              case when coalesce(r.bt->>'suppId', '') ~ '^[0-9]{1,18}$' then (r.bt->>'suppId')::bigint end,
              coalesce(r.bt->>'consignment', 'false') = 'true',
              nullif(public._fw_num(r.bt->'rates'->>'usdUzs'), 0), nullif(public._fw_num(r.bt->'rates'->>'usdCny'), 0),
              case when coalesce(r.bt->>'date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (r.bt->>'date')::date end,
              v_status, left(r.bt->>'performedBy', 200),
              case when r.bt->>'fromBranch' ~ '^[a-z0-9_]{1,40}$' then r.bt->>'fromBranch' end,
              left(r.bt->>'kirimRef', 64), left(r.bt->>'fkRef', 64))
      returning * into v_b;
    end if;
    insert into public.stock_ledger (filial, batch_id, batch_local_id, pid, d_qty, d_sold, qty_after, sold_after, cost_usd, status_after, op_kind, op_key, note)
      values (v_b.filial, v_b.id, v_b.local_id, v_b.pid, v_b.qty, v_b.sold, v_b.qty, v_b.sold, v_b.cost_usd, v_b.status, 'opening', 'opening:' || v_b.id,
              'Boshlang''ich qoldiq (27-migratsiya, ilovadagi qiymat)')
      on conflict (filial, op_key) do nothing;
  end loop;
  -- Ilovada yo'q (eskirgan soya) partiyalar — FIFO'dan chiqariladi ('deleted'), o'chirilmaydi
  for v_b in select b.* from public.batches b
              where b.filial = any(v_filials) and b.status is distinct from 'deleted'
                and not exists (select 1 from public.stock_ledger l where l.batch_id = b.id) loop
    insert into public.m27_stale_batches_archive (batch_id, filial, local_id, pid, qty, sold, cost_usd, original)
      values (v_b.id, v_b.filial, v_b.local_id, v_b.pid, v_b.qty, v_b.sold, v_b.cost_usd, to_jsonb(v_b))
      on conflict (batch_id) do nothing;
    update public.batches set status = 'deleted', deleted_at = now(), updated_at = now() where id = v_b.id;
    insert into public.stock_ledger (filial, batch_id, batch_local_id, pid, d_qty, d_sold, qty_after, sold_after, cost_usd, status_after, op_kind, op_key, note)
      values (v_b.filial, v_b.id, v_b.local_id, v_b.pid, v_b.qty, v_b.sold, v_b.qty, v_b.sold, v_b.cost_usd, 'deleted', 'archive', 'archive:' || v_b.id,
              'Ilovada yo''q partiya (eskirgan soya) — FIFO''dan chiqarildi')
      on conflict (filial, op_key) do nothing;
  end loop;

  -- 12d. Savdolar — qaytarish/tahrir/o'chirish serverdagi yozuvdan hisoblanishi uchun
  for r in
    with src as (
      select b.branch_key as filial, b.data from public.app_data_branches b where jsonb_typeof(b.data) = 'object'
      union all
      select s.key, s.value from public.app_data a, jsonb_each(coalesce(a.data->'branchStore', '{}'::jsonb)) s
       where a.id = 'main' and jsonb_typeof(s.value) = 'object'
         and not exists (select 1 from public.app_data_branches b2 where b2.branch_key = s.key and jsonb_typeof(b2.data) = 'object'))
    select src.filial, sl from src,
           jsonb_array_elements(case when jsonb_typeof(src.data->'sales') = 'array' then src.data->'sales' else '[]'::jsonb end) sl
     where jsonb_typeof(sl) = 'object' and coalesce(sl->>'id', '') ~ '^[0-9A-Za-z_.:-]{1,64}$'
  loop
    continue when exists (select 1 from public.sales where filial = r.filial and local_id = r.sl->>'id');
    v_inv := left(coalesce(nullif(r.sl->>'inv', ''), 'S-' || (r.sl->>'id')), 40);
    select coalesce(jsonb_agg(jsonb_build_object('pid', public._fw_num(i->>'pid')::bigint, 'sku', left(i->>'sku', 80), 'name', left(i->>'name', 300),
             'qty', public._fw_num(i->>'qty'), 'sell_usd', public._fw_num(i->>'sellUsd'), 'cost_usd', public._fw_num(i->>'costUsd'),
             'line_usd', public._fw_num(i->>'qty') * public._fw_num(i->>'sellUsd'),
             'direct_supply', coalesce(i->>'directSupply', 'false') = 'true',
             'supp_id', case when coalesce(i->>'suppId', '') ~ '^[0-9]{1,18}$' then (i->>'suppId')::bigint end) order by o), '[]'::jsonb)
      into v_items
      from jsonb_array_elements(case when jsonb_typeof(r.sl->'items') = 'array' then r.sl->'items' else '[]'::jsonb end) with ordinality as t(i, o)
     where jsonb_typeof(i) = 'object';
    update public.sales set local_id = r.sl->>'id', items = v_items,
           cust_id = case when coalesce(r.sl->>'custId', '') ~ '^[0-9]{1,18}$' then (r.sl->>'custId')::bigint end,
           subtotal_usd = public._fw_num(r.sl->>'subtotalUsd'), disc_pct = least(greatest(public._fw_num(r.sl->>'disc'), 0), 100),
           total_usd = public._fw_num(r.sl->>'totalUsd'), paid_usd = public._fw_num(r.sl->>'paidUsd'), debt_usd = public._fw_num(r.sl->>'debtUsd'),
           profit_usd = public._fw_num(r.sl->>'profitUsd'), disc_usd = public._fw_num(r.sl->>'discUsd'),
           pay_type = left(r.sl->>'payType', 20),
           box_id = case when coalesce(r.sl->>'boxId', '') ~ '^[0-9]{1,9}$' then (r.sl->>'boxId')::int end,
           mixed_rows = case when jsonb_typeof(r.sl->'mixedRows') = 'array' then r.sl->'mixedRows' end,
           cust_name = left(r.sl->>'custName', 200),
           sale_date = case when coalesce(r.sl->>'date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (r.sl->>'date')::date end,
           staff_name = left(r.sl->>'staffName', 200), is_transfer = coalesce(r.sl->>'isFilialTransfer', 'false') = 'true'
     where filial = r.filial and inv = v_inv and local_id is null;
    if not found then
      if exists (select 1 from public.sales where filial = r.filial and inv = v_inv) then
        v_inv := left(v_inv, 20) || '#' || right(r.sl->>'id', 19);
      end if;
      insert into public.sales (filial, inv, cust_id, subtotal_usd, disc_pct, total_usd, cost_usd, profit_usd, paid_usd, debt_usd, items,
                                local_id, pay_type, box_id, mixed_rows, cust_name, disc_usd, sale_date, status, staff_name, is_transfer)
      values (r.filial, v_inv, case when coalesce(r.sl->>'custId', '') ~ '^[0-9]{1,18}$' then (r.sl->>'custId')::bigint end,
              public._fw_num(r.sl->>'subtotalUsd'), least(greatest(public._fw_num(r.sl->>'disc'), 0), 100), public._fw_num(r.sl->>'totalUsd'),
              coalesce((select sum(public._fw_num(i->>'qty') * public._fw_num(i->>'cost_usd')) from jsonb_array_elements(v_items) i), 0),
              public._fw_num(r.sl->>'profitUsd'), public._fw_num(r.sl->>'paidUsd'), public._fw_num(r.sl->>'debtUsd'), v_items,
              r.sl->>'id', left(r.sl->>'payType', 20),
              case when coalesce(r.sl->>'boxId', '') ~ '^[0-9]{1,9}$' then (r.sl->>'boxId')::int end,
              case when jsonb_typeof(r.sl->'mixedRows') = 'array' then r.sl->'mixedRows' end,
              left(r.sl->>'custName', 200), public._fw_num(r.sl->>'discUsd'),
              case when coalesce(r.sl->>'date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (r.sl->>'date')::date end,
              'done', left(r.sl->>'staffName', 200), coalesce(r.sl->>'isFilialTransfer', 'false') = 'true');
    end if;
  end loop;

  perform set_config('fw.debt_move', '', true);
  perform set_config('fw.stock_move', '', true);
end $$;

-- v23.10: 27 avvalroq (arxiv jadvalisiz) qo'llangan bazada — FIFO'dan chiqarilgan partiyalar ham arxivga yoziladi
insert into public.m27_stale_batches_archive (batch_id, filial, local_id, pid, qty, sold, cost_usd, original, archived_at)
select b.id, b.filial, b.local_id, b.pid, b.qty, b.sold, b.cost_usd, to_jsonb(b), coalesce(b.deleted_at, now())
  from public.batches b
 where exists (select 1 from public.stock_ledger l where l.batch_id = b.id and l.op_kind = 'archive')
on conflict (batch_id) do nothing;

-- Yangi yozuvlar uchun: sotilgan ≤ miqdor (eski qatorlar tekshirilmaydi — NOT VALID; buzilgan bo'lsa ogohlantirish)
do $$
declare v_bad int;
begin
  if not exists (select 1 from pg_constraint where conname = 'batches_qty_sold_chk' and conrelid = 'public.batches'::regclass) then
    alter table public.batches add constraint batches_qty_sold_chk
      check (qty >= 0 and sold >= 0 and sold <= qty + 0.000001 and status in ('active','empty','transit','deleted')) not valid;
  end if;
  select count(*) into v_bad from public.batches where not (qty >= 0 and sold >= 0 and sold <= qty + 0.000001 and status in ('active','empty','transit','deleted'));
  if v_bad > 0 then
    raise warning '27-migratsiya: % ta partiya qatori qty/sold/status qoidasiga mos emas (tekshiring)', v_bad;
  end if;
end $$;

-- ── 13. Ruxsatlar: faqat server ─────────────────────────────────────────
revoke all on function public._debt_balances_guard() from public, anon, authenticated;
revoke all on function public._batches_guard() from public, anon, authenticated;
revoke all on function public._fw_num(text) from public, anon, authenticated;
revoke all on function public._fw_rate() from public, anon, authenticated;
revoke all on function public._cust_debt_move(text, bigint, numeric, text, text, text, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public._supp_debt_move(text, bigint, numeric, numeric, text, text, text, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public._stock_move(bigint, numeric, numeric, text, text, text, text, text, text, bigint, text, text, numeric) from public, anon, authenticated;
revoke all on function public._batch_insert(text, text, bigint, numeric, numeric, text, jsonb, text, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public._branch_debt_add(text, numeric) from public, anon, authenticated;
revoke all on function public._stock_fifo_out(text, bigint, numeric, text, text, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public._fw_apply_side_debts(text, jsonb, numeric, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public._fw_authority(text, bigint[], bigint[], bigint[]) from public, anon, authenticated;
revoke all on function public._fw_sale_json(public.sales) from public, anon, authenticated;
revoke all on function public._ledger_op_replay(text, text, text) from public, anon, authenticated;
revoke all on function public._ledger_op_finish(text, text, text, jsonb, bigint[], bigint[], bigint[], bigint, text) from public, anon, authenticated;
revoke all on function public.sale_checkout_atomic_v3(text, text, jsonb, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.sale_checkout_atomic_v2(text, jsonb, numeric, numeric, bigint, jsonb, text) from public, anon, authenticated;
revoke all on function public.sale_return_atomic(text, text, text, bigint, numeric, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.sale_void_atomic(text, text, text, jsonb, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.sale_edit_atomic(text, text, text, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.cash_payment_atomic(text, text, text, jsonb, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.cash_payment_atomic_v2(text, text, text, jsonb, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.stock_debt_op(text, text, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.app_data_save_main(jsonb) from public, anon, authenticated;
grant execute on function public.sale_checkout_atomic_v3(text, text, jsonb, jsonb, bigint, text) to service_role;
grant execute on function public.sale_checkout_atomic_v2(text, jsonb, numeric, numeric, bigint, jsonb, text) to service_role;
grant execute on function public.sale_return_atomic(text, text, text, bigint, numeric, text, jsonb, bigint, text) to service_role;
grant execute on function public.sale_void_atomic(text, text, text, jsonb, jsonb, bigint, text) to service_role;
grant execute on function public.sale_edit_atomic(text, text, text, text, jsonb, bigint, text) to service_role;
grant execute on function public.cash_payment_atomic(text, text, text, jsonb, text, jsonb, bigint, text) to service_role;
grant execute on function public.cash_payment_atomic_v2(text, text, text, jsonb, text, jsonb, bigint, text) to service_role;
grant execute on function public.stock_debt_op(text, text, text, jsonb, bigint, text) to service_role;
grant execute on function public.app_data_save_main(jsonb) to service_role;
grant execute on function public._fw_authority(text, bigint[], bigint[], bigint[]) to service_role;

comment on table public.ledger_ops is 'F4b (27-migratsiya): murakkab ombor/qarz amallari — idempotent natija (takror so''rov ikkinchi marta yozilmaydi)';
comment on table public.stock_ledger is 'F4b: ombor qoldig''i jurnali (o''zgarmas). batches.qty/sold faqat shu orqali o''zgaradi';
comment on table public.customer_debt_ledger is 'F4b: mijoz qarzi jurnali (so''m, o''zgarmas). customer_balances.debt faqat shu orqali';
comment on table public.supplier_debt_ledger is 'F4b: ta''minotchi qarzi jurnali ($, o''zgarmas). supplier_balances.debt faqat shu orqali';

-- ────────────────────────────────────────────────────────────────────
-- 12. 28-migratsiya: FIRMA KASSASI — asosiy kassa (xarajat, ta'minotchi to'lovi)
-- (supabase-migration-28-firma-kassa-asosiy.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 28-MIGRATSIYA (v23.4): FIRMA KASSASI — ASOSIY KASSA
--   • Kunlik yopish («Uyga berish») — pul tizimdan chiqmaydi: filial kassasi → Firma kassasi
--     (mavjud branch_firma_transfer orqali, bu yerda o'zgarish yo'q).
--   • Firma kassasidan XARAJAT (op_type = 'expense', ref_type = 'expense').
--   • Firma kassasidan TA'MINOTCHIGA QARZ TO'LOVI — kassa va qarz BITTA tranzaksiyada
--     (firma_supplier_pay; qarz jurnali 27-migratsiyadagi _supp_debt_move orqali, qarzdan ortiq — rad).
--   • Xarajat yozuvini bekor qilish faqat Xarajatlar bo'limidan (firma_kassa_reverse_expense).
-- Faqat qo'shadi / kengaytiradi; ma'lumot o'chirmaydi; qayta ishga tushirish xavfsiz.
-- Talab: 23, 25 va 27-migratsiyalar. Har doim 27 dan KEYIN.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.firma_kassa_ledger') is null or to_regclass('public.ledger_ops') is null
     or not exists (select 1 from pg_proc where proname = '_supp_debt_move')
     or not exists (select 1 from pg_proc where proname = 'firma_kassa_reverse') then
    raise exception '28-migratsiya: avval 23, 25 va 27-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Amal turlari va manba turlari ───────────────────────────────────
alter table public.firma_kassa_ledger drop constraint if exists firma_kassa_ledger_op_chk;
alter table public.firma_kassa_ledger add constraint firma_kassa_ledger_op_chk check (
  (direction = 'in'  and op_type in ('deposit','branch_in','advance_repay','adjust_in','opening','reversal_in')) or
  (direction = 'out' and op_type in ('withdraw','branch_out','advance_give','kirim_payment','partner_withdrawal','adjust_out','reversal_out',
                                     'expense','supplier_payment'))
);

create or replace function public._fk_source_type(p_op_type text, p_cp_type text, p_ref_type text)
 returns text
 language sql
 immutable
 set search_path = ''
as $$
  select case
    when p_op_type = 'opening' then 'opening_balance'
    when p_op_type in ('adjust_in','adjust_out') then 'manual_adjustment'
    when p_op_type = 'deposit' and p_ref_type = 'expense' then 'partner_deposit'
    when p_op_type = 'deposit' then 'deposit'
    when p_op_type = 'withdraw' then 'withdraw'
    when p_op_type = 'branch_in' and p_ref_type = 'branch_debt' then 'branch_debt_payment'
    when p_op_type = 'branch_in' then 'branch_transfer_in'
    when p_op_type = 'branch_out' then 'branch_transfer_out'
    when p_op_type = 'advance_give' and p_cp_type = 'branch' then 'branch_loan'
    when p_op_type = 'advance_give' then 'advance_given'
    when p_op_type = 'advance_repay' then 'advance_repayment'
    when p_op_type = 'kirim_payment' and p_ref_type = 'kirim_shortfall' then 'kirim_shortfall'
    when p_op_type = 'kirim_payment' then 'kirim_payment'
    when p_op_type = 'partner_withdrawal' then 'partner_withdrawal'
    when p_op_type = 'expense' then 'expense'
    when p_op_type = 'supplier_payment' then 'supplier_payment'
    when p_op_type in ('reversal_in','reversal_out') then 'reversal'
  end
$$;

alter table public.firma_kassa_ledger drop constraint if exists firma_kassa_ledger_source_chk;
alter table public.firma_kassa_ledger add constraint firma_kassa_ledger_source_chk check (source_type is not null and source_type in (
  'opening_balance','manual_adjustment','deposit','withdraw','branch_debt_payment','branch_transfer_in','branch_transfer_out',
  'branch_loan','advance_given','advance_repayment','kirim_payment','kirim_shortfall','partner_withdrawal','reversal',
  'expense','supplier_payment','partner_deposit'));

alter table public.ledger_ops drop constraint if exists ledger_ops_kind_chk;
alter table public.ledger_ops add constraint ledger_ops_kind_chk check (kind in ('sale','sale_return','sale_void','sale_edit','cust_set','supp_set',
  'batches_create','batch_edit','batch_delete','batch_arrive','revision','stock_out','firma_supp_pay'));

-- ── 2. Umumiy bekor qilish: xarajat va ta'minotchi to'lovi bu yerda bekor qilinmaydi ──
create or replace function public.firma_kassa_reverse(
  p_entry_id bigint, p_idem_key text, p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns public.firma_kassa_ledger
 language plpgsql
 set search_path = ''
as $$
declare
  v_orig public.firma_kassa_ledger;
  v_rev public.firma_kassa_ledger;
  v_key text;
begin
  if coalesce(p_idem_key, '') = '' or length(p_idem_key) > 100 then
    raise exception 'FIRMA_KASSA: amal kaliti majburiy' using errcode = 'P0001';
  end if;
  v_key := 'rev:' || p_idem_key;
  select * into v_rev from public.firma_kassa_ledger where idem_key = v_key;
  if found then
    if v_rev.reversal_of is distinct from p_entry_id then
      raise exception 'FIRMA_KASSA: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    return v_rev;
  end if;

  select * into v_orig from public.firma_kassa_ledger where id = p_entry_id for update;
  if not found then
    raise exception 'FIRMA_KASSA: yozuv topilmadi' using errcode = 'P0001';
  end if;
  if v_orig.reversed_by is not null then
    raise exception 'FIRMA_KASSA: bu yozuv allaqachon bekor qilingan' using errcode = 'P0001';
  end if;
  if v_orig.op_type in ('reversal_in','reversal_out') then
    raise exception 'FIRMA_KASSA: teskari yozuvni bekor qilib bo''lmaydi' using errcode = 'P0001';
  end if;
  -- Filial kassasi bilan bog'langan yozuvlar (filial bilan o'tkazma, qarz to'lovi, filial qarzi)
  -- ikkala tomonda ham bekor qilinishi kerak — bu yerda emas (teskari amal bilan bajariladi)
  -- 28: xarajat yozuvi — faqat Xarajatlar bo'limidan (firma_kassa_reverse_expense) bekor qilinadi (JSON yozuvi ham o'chadi);
  -- ta'minotchiga to'lov — qarz jurnali bilan bog'langan, bu yerda bekor qilinmaydi
  if coalesce(v_orig.ref_type, '') = 'expense' then
    raise exception 'FIRMA_KASSA: xarajat yozuvini Xarajatlar bo''limidan o''chiring (kassa va xarajat birga qaytadi)' using errcode = 'P0001';
  end if;
  if v_orig.op_type = 'supplier_payment' then
    raise exception 'FIRMA_KASSA: ta''minotchiga to''lov qarz jurnali bilan bog''langan — bu yerda bekor qilib bo''lmaydi' using errcode = 'P0001';
  end if;
  if v_orig.op_type in ('branch_in','branch_out') or v_orig.counterparty_type = 'branch' or coalesce(v_orig.idem_key, '') like 'bf%' then
    raise exception 'FIRMA_KASSA: filial bilan bog''liq yozuvni bu yerda bekor qilib bo''lmaydi — teskari amal (filialga qaytarish) qiling' using errcode = 'P0001';
  end if;
  if v_orig.op_type = 'advance_give'
     and public.firma_kassa_advance_outstanding(v_orig.currency, v_orig.counterparty_type, v_orig.counterparty_id) < v_orig.amount then
    raise exception 'FIRMA_KASSA: avansning bir qismi qaytarilgan — avval qaytarishlarni bekor qiling' using errcode = 'P0001';
  end if;

  v_rev := public._fk_cash_move(v_orig.currency, case when v_orig.direction = 'in' then 'out' else 'in' end, v_orig.amount,
            case when v_orig.direction = 'in' then 'reversal_out' else 'reversal_in' end,
            v_orig.counterparty_type, v_orig.counterparty_id, v_orig.counterparty_name, v_orig.filial,
            'reversal', v_orig.id::text, left(coalesce(p_note, '') || ' (bekor: #' || v_orig.id || ')', 500), p_staff_id, p_staff_name, v_key);
  update public.firma_kassa_ledger set reversed_by = v_rev.id, reversed_at = now() where id = v_orig.id;
  return v_rev;
end;
$$;


-- ── 3. Xarajat yozuvini bekor qilish (Xarajatlar bo'limidan o'chirilganda) ──
create or replace function public.firma_kassa_reverse_expense(
  p_entry_id bigint, p_idem_key text, p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns public.firma_kassa_ledger
 language plpgsql
 set search_path = ''
as $$
declare
  v_orig public.firma_kassa_ledger;
  v_rev public.firma_kassa_ledger;
  v_key text;
begin
  if coalesce(p_idem_key, '') = '' or length(p_idem_key) > 100 then
    raise exception 'FIRMA_KASSA: amal kaliti majburiy' using errcode = 'P0001';
  end if;
  v_key := 'rev:' || p_idem_key;
  select * into v_rev from public.firma_kassa_ledger where idem_key = v_key;
  if found then
    if v_rev.reversal_of is distinct from p_entry_id then
      raise exception 'FIRMA_KASSA: amal kaliti boshqa amal uchun ishlatilgan' using errcode = 'P0001';
    end if;
    return v_rev;
  end if;
  select * into v_orig from public.firma_kassa_ledger where id = p_entry_id for update;
  if not found then
    raise exception 'FIRMA_KASSA: yozuv topilmadi' using errcode = 'P0001';
  end if;
  if coalesce(v_orig.ref_type, '') <> 'expense' or v_orig.op_type not in ('expense','deposit') then
    raise exception 'FIRMA_KASSA: bu xarajat yozuvi emas' using errcode = 'P0001';
  end if;
  if v_orig.reversed_by is not null then
    raise exception 'FIRMA_KASSA: bu yozuv allaqachon bekor qilingan' using errcode = 'P0001';
  end if;
  v_rev := public._fk_cash_move(v_orig.currency, case when v_orig.direction = 'in' then 'out' else 'in' end, v_orig.amount,
            case when v_orig.direction = 'in' then 'reversal_out' else 'reversal_in' end,
            v_orig.counterparty_type, v_orig.counterparty_id, v_orig.counterparty_name, v_orig.filial,
            'reversal', v_orig.id::text, left(coalesce(p_note, '') || ' (xarajat bekor: #' || v_orig.id || ')', 500), p_staff_id, p_staff_name, v_key);
  update public.firma_kassa_ledger set reversed_by = v_rev.id, reversed_at = now() where id = v_orig.id;
  return v_rev;
end;
$$;

-- ── 4. Firma kassasidan ta'minotchi qarzini to'lash — kassa + qarz BITTA tranzaksiyada ──
-- Qulf tartibi (27 bilan bir xil): ta'minotchi → kassa. Qarzdan ortiq to'lov — rad (1 sent tolerantlik).
-- Takroriy so'rov (bir xil p_op_key) — birinchi natija qaytadi, ikkinchi marta yozilmaydi.
create or replace function public.firma_supplier_pay(
  p_filial text, p_supp bigint, p_currency text, p_amount numeric, p_op_key text,
  p_supp_name text default null, p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  v_amt numeric;
  v_usd numeric;
  v_debt numeric;
  v_fk public.firma_kassa_ledger;
  v_res jsonb;
begin
  if coalesce(p_filial, '') = '' or p_supp is null or p_supp <= 0 then
    raise exception 'LEDGER: ta''minotchi noto''g''ri' using errcode = 'P0001';
  end if;
  if p_currency is null or p_currency not in ('USD','UZS') then
    raise exception 'FIRMA_KASSA: valyuta faqat USD yoki UZS' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 10000000000000 then
    raise exception 'FIRMA_KASSA: summa musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'firma_supp_pay');
  if v_prev is not null then return v_prev; end if;

  v_amt := round(p_amount, 2);
  v_usd := case when p_currency = 'USD' then v_amt else round(v_amt / public._fw_rate(), 4) end;
  if v_usd <= 0 then raise exception 'FIRMA_KASSA: summa juda kichik' using errcode = 'P0001'; end if;

  v_debt := public._supp_debt_move(p_filial, p_supp, -v_usd, v_usd, 'strict', 'payment', 'fsp:' || p_op_key, p_op_key,
                                   'firma_kassa', null, left(coalesce(p_supp_name, ''), 200), p_staff_id, p_staff_name);
  v_fk := public._fk_cash_move(p_currency, 'out', v_amt, 'supplier_payment', 'supplier', p_supp::text, left(p_supp_name, 200),
                               p_filial, 'supplier_debt', p_supp::text, p_note, p_staff_id, p_staff_name, 'fsp:' || p_filial || ':' || p_op_key);
  insert into public.supplier_payments (filial, supplier_local_id, supplier_name, amount_usd, box_local_id, staff_id, staff_name, idem_key)
  values (p_filial, p_supp, left(p_supp_name, 200), v_usd, null, p_staff_id, left(p_staff_name, 200), 'fsp:' || p_op_key);

  v_res := jsonb_build_object('ok', true, 'fkEntryId', v_fk.id, 'currency', p_currency, 'amount', v_amt, 'amountUsd', v_usd,
    'firmaBalance', v_fk.balance_after,
    'supplierDebt', (select debt from public.supplier_balances where filial = p_filial and supplier_local_id = p_supp),
    'supplierPaid', (select total_paid from public.supplier_balances where filial = p_filial and supplier_local_id = p_supp));
  return public._ledger_op_finish(p_filial, p_op_key, 'firma_supp_pay', v_res, null, array[p_supp], null, p_staff_id, p_staff_name);
end;
$$;

-- ── 5. Huquqlar: brauzer rollari chaqira olmaydi, faqat server (service_role) ──
revoke all on function public._fk_source_type(text, text, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_reverse(bigint, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.firma_kassa_reverse_expense(bigint, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.firma_supplier_pay(text, bigint, text, numeric, text, text, text, bigint, text) from public, anon, authenticated;
grant execute on function public._fk_source_type(text, text, text) to service_role;
grant execute on function public.firma_kassa_reverse(bigint, text, text, bigint, text) to service_role;
grant execute on function public.firma_kassa_reverse_expense(bigint, text, text, bigint, text) to service_role;
grant execute on function public.firma_supplier_pay(text, bigint, text, numeric, text, text, text, bigint, text) to service_role;

-- ────────────────────────────────────────────────────────────────────
-- 13. 29-migratsiya: HISOBDAN CHIQARISH va B2B (ko'chirilgan tizimlar o'rtasida ta'minot)
-- (supabase-migration-29-hisobdan-chiqarish-b2b.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 29-MIGRATSIYA (v23.6): HISOBDAN CHIQARISH va B2B (ko'chirilgan tizimlar o'rtasida ta'minot)
--   A. Hisobdan chiqarish (buzilgan, muddati o'tgan, singan, yo'qolgan tovar):
--      stock_writeoffs hujjati + ombordan FIFO chiqim (stock_ledger 'writeoff') BITTA tranzaksiyada;
--      bekor qilish — aynan o'sha partiyalarga qaytariladi ('writeoff_cancel'). Zarar = tannarx × soni
--      (ilovada «Hisobdan chiqarish zarari» tizim xarajati bo'lib sof foydadan ayiriladi; kassaga tegmaydi).
--   B. B2B: ikki mustaqil nusxa (har biri o'z bazasi) havola+kod orqali ulanadi, IKKALA tomon o'z
--      huquqlarini beradi. Buyurtma → jo'natma (ta'minotchi omboridan FIFO chiqim) → qabul qiluvchi
--      sonini tekshirib tasdiqlaydi → uning omboriga kirim + ta'minotchiga qarz; ta'minotchi tomonida
--      xaridor (mijoz) qarzi — faqat tasdiqlangan son bo'yicha. Kelmay qolgan qism ta'minotchi omboriga
--      qaytariladi ('b2b_restock').
-- Faqat qo'shadi / kengaytiradi; ma'lumot o'chirmaydi; qayta ishga tushirish xavfsiz.
-- Talab: 27 va 28-migratsiyalar. Har doim 28 dan KEYIN.
-- Maxfiy qiymatlar (B2B kalitlari) faqat service_role o'qiydigan jadvalda; brauzerga hech qachon berilmaydi.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.stock_ledger') is null or to_regclass('public.ledger_ops') is null
     or not exists (select 1 from pg_proc where proname = '_stock_fifo_out')
     or not exists (select 1 from pg_proc where proname = 'firma_supplier_pay') then
    raise exception '29-migratsiya: avval 27 va 28-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Amal turlari ────────────────────────────────────────────────────
alter table public.stock_ledger drop constraint if exists stock_ledger_kind_chk;
alter table public.stock_ledger add constraint stock_ledger_kind_chk check (op_kind in ('opening','archive','sale','sale_edit','sale_void','sale_return','kirim','import',
  'opening_stock','edit','delete','arrive','revision','transfer_out','transfer_in','dealer_out','dealer_return',
  'writeoff','writeoff_cancel','b2b_out','b2b_in','b2b_restock'));
alter table public.ledger_ops drop constraint if exists ledger_ops_kind_chk;
alter table public.ledger_ops add constraint ledger_ops_kind_chk check (kind in ('sale','sale_return','sale_void','sale_edit','cust_set','supp_set',
  'batches_create','batch_edit','batch_delete','batch_arrive','revision','stock_out','firma_supp_pay',
  'writeoff','writeoff_cancel','b2b_ship','b2b_receive','b2b_ack','b2b_restock'));
alter table public.supplier_debt_ledger drop constraint if exists supplier_debt_ledger_kind_chk;
alter table public.supplier_debt_ledger add constraint supplier_debt_ledger_kind_chk check (op_kind in ('opening','adjust','sale_direct','consignment','sale_return','kirim','import','batch_edit','payment',
  'writeoff_cancel','b2b_receive','b2b_restock'));
alter table public.customer_debt_ledger drop constraint if exists customer_debt_ledger_kind_chk;
alter table public.customer_debt_ledger add constraint customer_debt_ledger_kind_chk check (op_kind in ('opening','adjust','sale','sale_edit','sale_void','sale_return','payment',
  'b2b_ship'));

-- ── 2. Jadvallar ───────────────────────────────────────────────────────
create table if not exists public.stock_writeoffs (
  id bigint generated always as identity primary key,
  filial text not null,
  local_id text not null,
  doc_no text not null,
  reason text not null,
  note text,
  items jsonb not null default '[]'::jsonb,       -- [{pid, sku, name, qty, cost, allocs:[{batchId, localId, take, cost}]}]
  side jsonb not null default '[]'::jsonb,        -- konsignatsiya qarzi (bekor qilishda teskari)
  bd numeric not null default 0,                  -- filialning Bazaga tovar qarzi ulushi
  units numeric not null default 0,
  total_cost_usd numeric not null default 0,
  status text not null default 'active',
  wo_date date not null default current_date,
  created_at timestamp with time zone not null default now(),
  staff_id bigint, staff_name text,
  cancelled_at timestamp with time zone, cancel_staff text, cancel_note text,
  constraint stock_writeoffs_local_key unique (filial, local_id),
  constraint stock_writeoffs_reason_chk check (reason in ('damaged','expired','broken','lost','other')),
  constraint stock_writeoffs_status_chk check (status in ('active','cancelled')),
  constraint stock_writeoffs_text_len check (length(local_id) <= 64 and length(doc_no) <= 40 and coalesce(length(note),0) <= 500
    and coalesce(length(cancel_note),0) <= 500 and coalesce(length(staff_name),0) <= 200)
);
create index if not exists idx_stock_writeoffs_filial_date on public.stock_writeoffs (filial, wo_date desc);

create table if not exists public.b2b_links (
  id bigint generated always as identity primary key,
  link_uid text not null unique,
  filial text not null default 'baza',
  peer_url text, peer_name text, peer_link_uid text,
  status text not null default 'invited',
  local_approved boolean not null default false,
  peer_approved boolean not null default false,
  perm_catalog boolean not null default true,      -- hamkor BIZNING katalogni ko'ra oladi
  perm_order boolean not null default true,        -- hamkor BIZGA buyurtma bera oladi
  we_supply boolean not null default true,         -- biz unga ta'minotchimiz
  they_supply boolean not null default true,       -- u bizga ta'minotchi
  supplier_local_id bigint,                        -- bizdagi «ta'minotchi» yozuvi (u bizga yetkazsa)
  customer_local_id bigint,                        -- bizdagi «mijoz» yozuvi (biz unga yetkazsak)
  inbound_token_hash text,                         -- hamkor bizga murojaatda ko'rsatadigan kalitning SHA-256 xeshi
  outbound_token text,                             -- biz hamkorga murojaatda ko'rsatadigan kalit (faqat server)
  invite_secret_hash text, invite_expires_at timestamp with time zone,
  note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  approved_at timestamp with time zone,
  constraint b2b_links_status_chk check (status in ('invited','pending','active','paused','revoked')),
  constraint b2b_links_uid_chk check (link_uid ~ '^[A-Za-z0-9]{20,48}$' and (peer_link_uid is null or peer_link_uid ~ '^[A-Za-z0-9]{20,48}$')),
  constraint b2b_links_url_chk check (peer_url is null or (peer_url ~ '^https://[A-Za-z0-9.-]+(:[0-9]{2,5})?$' and length(peer_url) <= 200)),
  constraint b2b_links_text_len check (coalesce(length(peer_name),0) <= 120 and coalesce(length(note),0) <= 500 and filial ~ '^[a-z0-9_]{1,40}$')
);

create table if not exists public.b2b_orders (
  id bigint generated always as identity primary key,
  link_id bigint not null references public.b2b_links(id),
  filial text not null,
  order_uid text not null,
  direction text not null,                         -- 'out' — biz buyurtma berdik; 'in' — bizga buyurtma
  status text not null default 'draft',
  items jsonb not null default '[]'::jsonb,        -- [{peerPid, pid, sku, name, qty, priceUsd, confQty, confPrice}]
  total_usd numeric not null default 0,
  note text,
  delivered boolean not null default false,        -- hamkorga yetkazildimi (tarmoq)
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  staff_name text,
  constraint b2b_orders_uid_key unique (link_id, order_uid, direction),
  constraint b2b_orders_dir_chk check (direction in ('out','in')),
  constraint b2b_orders_status_chk check (status in ('draft','sent','confirmed','rejected','shipped','closed','cancelled')),
  constraint b2b_orders_text_len check (order_uid ~ '^[A-Za-z0-9_-]{8,64}$' and coalesce(length(note),0) <= 500)
);
create index if not exists idx_b2b_orders_link on public.b2b_orders (link_id, created_at desc);

create table if not exists public.b2b_shipments (
  id bigint generated always as identity primary key,
  link_id bigint not null references public.b2b_links(id),
  filial text not null,
  ship_uid text not null,
  order_uid text,
  direction text not null,                         -- 'out' — biz jo'natdik; 'in' — bizga keldi
  status text not null,                            -- out: sent → acked → (restocked) ; in: awaiting → received | rejected
  items jsonb not null default '[]'::jsonb,
  total_usd numeric not null default 0,
  received_total_usd numeric,
  rate_uzs numeric,
  delivered boolean not null default false,
  note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  received_at timestamp with time zone,
  staff_name text,
  constraint b2b_shipments_uid_key unique (link_id, ship_uid, direction),
  constraint b2b_shipments_dir_chk check (direction in ('out','in')),
  constraint b2b_shipments_status_chk check (status in ('sent','acked','restocked','awaiting','received','rejected')),
  constraint b2b_shipments_text_len check (ship_uid ~ '^[A-Za-z0-9_-]{8,64}$' and (order_uid is null or order_uid ~ '^[A-Za-z0-9_-]{8,64}$')
    and coalesce(length(note),0) <= 500)
);
create index if not exists idx_b2b_shipments_link on public.b2b_shipments (link_id, created_at desc);

create table if not exists public.b2b_product_map (
  link_id bigint not null references public.b2b_links(id),
  peer_pid bigint not null,
  local_pid bigint not null,
  peer_sku text,
  updated_at timestamp with time zone not null default now(),
  primary key (link_id, peer_pid)
);

-- Hamkordan kelgan xabarlar — takroriy yetkazishni bir marta qo'llash uchun
create table if not exists public.b2b_inbound_log (
  link_id bigint not null references public.b2b_links(id),
  msg_id text not null,
  action text not null,
  result jsonb,
  created_at timestamp with time zone not null default now(),
  primary key (link_id, msg_id),
  constraint b2b_inbound_msg_chk check (msg_id ~ '^[A-Za-z0-9_:-]{8,100}$')
);

alter table public.stock_writeoffs enable row level security;
alter table public.b2b_links enable row level security;
alter table public.b2b_orders enable row level security;
alter table public.b2b_shipments enable row level security;
alter table public.b2b_product_map enable row level security;
alter table public.b2b_inbound_log enable row level security;
revoke all on public.stock_writeoffs, public.b2b_links, public.b2b_orders, public.b2b_shipments, public.b2b_product_map, public.b2b_inbound_log
  from anon, authenticated;
grant select, insert, update on public.stock_writeoffs, public.b2b_links, public.b2b_orders, public.b2b_shipments, public.b2b_product_map, public.b2b_inbound_log
  to service_role;
grant delete on public.b2b_product_map to service_role;

-- ── 3. HISOBDAN CHIQARISH ──────────────────────────────────────────────
-- p_doc: {localId, docNo, reason, note, date, items:[{pid, sku, name, qty}]}
create or replace function public.stock_writeoff_atomic(
  p_filial text, p_op_key text, p_doc jsonb, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  v_key text := 'wo:' || p_op_key;
  v_e jsonb;
  v_n int := 0;
  v_pid bigint;
  v_qty numeric;
  v_fifo jsonb;
  v_side jsonb := '[]'::jsonb;
  v_bd numeric := 0;
  v_items jsonb := '[]'::jsonb;
  v_batches bigint[] := '{}';
  v_supps bigint[];
  v_units numeric := 0;
  v_total numeric := 0;
  v_local text := p_doc->>'localId';
  v_date date;
begin
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'writeoff');
  if v_prev is not null then return v_prev; end if;
  if coalesce(v_local, '') !~ '^[0-9A-Za-z_.:-]{1,64}$' then raise exception 'LEDGER: hujjat ID noto''g''ri' using errcode = 'P0001'; end if;
  if coalesce(p_doc->>'reason', '') not in ('damaged','expired','broken','lost','other') then
    raise exception 'LEDGER: sabab noto''g''ri' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_doc->'items') <> 'array' or jsonb_array_length(p_doc->'items') < 1 or jsonb_array_length(p_doc->'items') > 200 then
    raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.stock_writeoffs where filial = p_filial and local_id = v_local) then
    raise exception 'LEDGER: hujjat ID takrorlandi' using errcode = 'P0001';
  end if;
  v_date := case when coalesce(p_doc->>'date', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (p_doc->>'date')::date else current_date end;
  for v_e in select e from jsonb_array_elements(p_doc->'items') e order by public._fw_num(e->>'pid') loop
    v_n := v_n + 1;
    v_pid := public._fw_num(v_e->>'pid')::bigint;
    v_qty := public._fw_num(v_e->>'qty');
    if v_pid is null or v_pid <= 0 then raise exception 'LEDGER: mahsulot noto''g''ri' using errcode = 'P0001'; end if;
    v_fifo := public._stock_fifo_out(p_filial, v_pid, v_qty, 'writeoff', v_key || ':' || v_n, v_key, 'writeoff', v_local,
                                     'Hisobdan chiqarish: ' || (p_doc->>'reason'), p_staff_id, p_staff_name);
    v_side := v_side || (v_fifo->'side');
    v_bd := v_bd + (v_fifo->>'bd')::numeric;
    v_batches := v_batches || array(select (a->>'batchId')::bigint from jsonb_array_elements(v_fifo->'allocs') a);
    v_units := v_units + v_qty;
    v_total := v_total + (v_fifo->>'cost')::numeric;
    v_items := v_items || jsonb_build_object('pid', v_pid, 'sku', left(v_e->>'sku', 80), 'name', left(v_e->>'name', 300), 'qty', v_qty,
                                             'cost', (v_fifo->>'cost')::numeric, 'allocs', v_fifo->'allocs');
  end loop;
  v_supps := public._fw_apply_side_debts(p_filial, v_side, v_bd, v_key, v_key, 'writeoff', v_local, p_staff_id, p_staff_name);
  insert into public.stock_writeoffs (filial, local_id, doc_no, reason, note, items, side, bd, units, total_cost_usd, wo_date, staff_id, staff_name)
  values (p_filial, v_local, left(coalesce(p_doc->>'docNo', v_local), 40), p_doc->>'reason', left(p_doc->>'note', 500), v_items, v_side, v_bd,
          v_units, round(v_total, 4), v_date, p_staff_id, left(p_staff_name, 200));
  return public._ledger_op_finish(p_filial, p_op_key, 'writeoff',
    jsonb_build_object('ok', true, 'kind', 'writeoff', 'localId', v_local, 'units', v_units, 'totalCostUsd', round(v_total, 4), 'items', v_items),
    '{}', v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- Bekor qilish: aynan o'sha partiyalarga qaytariladi (FIFO tannarxi saqlanadi), konsignatsiya qarzi va
-- filialning Bazaga qarzi teskari yoziladi. Partiya o'chirilgan bo'lsa — rad (jimgina emas).
create or replace function public.stock_writeoff_cancel(
  p_filial text, p_op_key text, p_local_id text, p_note text default null, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  w public.stock_writeoffs;
  v_key text := 'woc:' || p_op_key;
  v_it jsonb;
  v_a jsonb;
  v_n int := 0;
  v_batches bigint[] := '{}';
  v_supps bigint[] := '{}';
  r record;
begin
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'writeoff_cancel');
  if v_prev is not null then return v_prev; end if;
  select * into w from public.stock_writeoffs where filial = p_filial and local_id = p_local_id for update;
  if not found then raise exception 'LEDGER: hujjat topilmadi' using errcode = 'P0001'; end if;
  if w.status <> 'active' then raise exception 'LEDGER: hujjat allaqachon bekor qilingan' using errcode = 'P0001'; end if;
  for v_it in select * from jsonb_array_elements(w.items) loop
    for v_a in select * from jsonb_array_elements(coalesce(v_it->'allocs', '[]'::jsonb)) order by public._fw_num(value->>'batchId') loop
      v_n := v_n + 1;
      perform public._stock_move((v_a->>'batchId')::bigint, 0, -public._fw_num(v_a->>'take'), 'writeoff_cancel', v_key || ':' || v_n,
                                 v_key, 'writeoff', w.local_id, 'Hisobdan chiqarish bekor qilindi', p_staff_id, p_staff_name);
      v_batches := v_batches || (v_a->>'batchId')::bigint;
    end loop;
  end loop;
  for r in select (e->>'supp')::bigint as supp, sum(public._fw_num(e->>'usd')) as usd from jsonb_array_elements(w.side) e group by 1 order by 1 loop
    continue when r.usd = 0;
    perform public._supp_debt_move(p_filial, r.supp, -r.usd, 0, 'strict', 'writeoff_cancel', v_key || ':s:' || r.supp, v_key, 'writeoff', w.local_id,
                                   'Hisobdan chiqarish bekor qilindi (konsignatsiya)', p_staff_id, p_staff_name);
    v_supps := v_supps || r.supp;
  end loop;
  if coalesce(w.bd, 0) > 0 then perform public._branch_debt_add(p_filial, -w.bd); end if;
  update public.stock_writeoffs set status = 'cancelled', cancelled_at = now(), cancel_staff = left(p_staff_name, 200), cancel_note = left(p_note, 500)
   where id = w.id;
  return public._ledger_op_finish(p_filial, p_op_key, 'writeoff_cancel',
    jsonb_build_object('ok', true, 'kind', 'writeoff_cancel', 'localId', w.local_id, 'totalCostUsd', w.total_cost_usd),
    '{}', v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 4. B2B: jo'natish (ta'minotchi tomoni) ─────────────────────────────
-- p_ship: {shipUid, orderUid, note, items:[{pid, sku, name, qty, priceUsd}]}
create or replace function public.b2b_ship_atomic(
  p_filial text, p_op_key text, p_link_id bigint, p_ship jsonb, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  l public.b2b_links;
  v_key text := 'b2s:' || p_op_key;
  v_uid text := p_ship->>'shipUid';
  v_e jsonb;
  v_n int := 0;
  v_pid bigint;
  v_qty numeric;
  v_price numeric;
  v_fifo jsonb;
  v_side jsonb := '[]'::jsonb;
  v_bd numeric := 0;
  v_items jsonb := '[]'::jsonb;
  v_batches bigint[] := '{}';
  v_supps bigint[];
  v_total numeric := 0;
begin
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'b2b_ship');
  if v_prev is not null then return v_prev; end if;
  select * into l from public.b2b_links where id = p_link_id for update;
  if not found or l.status <> 'active' or not l.local_approved or not l.we_supply then
    raise exception 'LEDGER: B2B ulanish faol emas yoki siz bu hamkorga ta''minotchi emassiz' using errcode = 'P0001';
  end if;
  if l.filial <> p_filial then raise exception 'LEDGER: B2B ulanish boshqa filialga tegishli' using errcode = 'P0001'; end if;
  if coalesce(v_uid, '') !~ '^[A-Za-z0-9_-]{8,64}$' then raise exception 'LEDGER: jo''natma ID noto''g''ri' using errcode = 'P0001'; end if;
  if jsonb_typeof(p_ship->'items') <> 'array' or jsonb_array_length(p_ship->'items') < 1 or jsonb_array_length(p_ship->'items') > 300 then
    raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
  end if;
  for v_e in select e from jsonb_array_elements(p_ship->'items') e order by public._fw_num(e->>'pid') loop
    v_n := v_n + 1;
    v_pid := public._fw_num(v_e->>'pid')::bigint;
    v_qty := public._fw_num(v_e->>'qty');
    v_price := public._fw_num(v_e->>'priceUsd');
    if v_pid is null or v_pid <= 0 then raise exception 'LEDGER: mahsulot noto''g''ri' using errcode = 'P0001'; end if;
    if v_price < 0 or v_price > 10000000 then raise exception 'LEDGER: narx noto''g''ri' using errcode = 'P0001'; end if;
    v_fifo := public._stock_fifo_out(p_filial, v_pid, v_qty, 'b2b_out', v_key || ':' || v_n, v_key, 'b2b_ship', v_uid,
                                     'B2B jo''natma: ' || left(coalesce(l.peer_name, ''), 100), p_staff_id, p_staff_name);
    v_side := v_side || (v_fifo->'side');
    v_bd := v_bd + (v_fifo->>'bd')::numeric;
    v_batches := v_batches || array(select (a->>'batchId')::bigint from jsonb_array_elements(v_fifo->'allocs') a);
    v_total := v_total + v_qty * v_price;
    v_items := v_items || jsonb_build_object('pid', v_pid, 'sku', left(v_e->>'sku', 80), 'name', left(v_e->>'name', 300), 'qty', v_qty,
                                             'priceUsd', v_price, 'cost', (v_fifo->>'cost')::numeric, 'allocs', v_fifo->'allocs', 'side', v_fifo->'side');
  end loop;
  v_supps := public._fw_apply_side_debts(p_filial, v_side, v_bd, v_key, v_key, 'b2b_ship', v_uid, p_staff_id, p_staff_name);
  insert into public.b2b_shipments (link_id, filial, ship_uid, order_uid, direction, status, items, total_usd, note, staff_name)
  values (l.id, p_filial, v_uid, nullif(p_ship->>'orderUid', ''), 'out', 'sent', v_items, round(v_total, 4), left(p_ship->>'note', 500), left(p_staff_name, 200));
  if coalesce(p_ship->>'orderUid', '') <> '' then
    update public.b2b_orders set status = 'shipped', updated_at = now()
     where link_id = l.id and order_uid = p_ship->>'orderUid' and direction = 'in' and status in ('sent','confirmed');
  end if;
  return public._ledger_op_finish(p_filial, p_op_key, 'b2b_ship',
    jsonb_build_object('ok', true, 'kind', 'b2b_ship', 'shipUid', v_uid, 'totalUsd', round(v_total, 4), 'items', v_items),
    '{}', v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 5. B2B: qabul qilish (xaridor tomoni) — sonini tekshirib tasdiqlaydi ─
-- p_lines: [{idx, localPid, receivedQty, batchLocalId}] — narx jo'natmadagidek (o'zgartirilmaydi)
create or replace function public.b2b_receive_atomic(
  p_filial text, p_op_key text, p_link_id bigint, p_ship_uid text, p_lines jsonb, p_meta jsonb default '{}'::jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  l public.b2b_links;
  sh public.b2b_shipments;
  v_key text := 'b2r:' || p_op_key;
  v_e jsonb;
  v_it jsonb;
  v_idx int;
  v_rq numeric;
  v_pid bigint;
  v_price numeric;
  v_b public.batches;
  v_batches bigint[] := '{}';
  v_total numeric := 0;
  v_out jsonb := '[]'::jsonb;
  v_seen int[] := '{}';
begin
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'b2b_receive');
  if v_prev is not null then return v_prev; end if;
  select * into l from public.b2b_links where id = p_link_id for update;
  if not found or l.status <> 'active' or not l.local_approved or not l.they_supply or l.supplier_local_id is null then
    raise exception 'LEDGER: B2B ulanish faol emas yoki ta''minotchi yozuvi bog''lanmagan' using errcode = 'P0001';
  end if;
  if l.filial <> p_filial then raise exception 'LEDGER: B2B ulanish boshqa filialga tegishli' using errcode = 'P0001'; end if;
  select * into sh from public.b2b_shipments where link_id = l.id and ship_uid = p_ship_uid and direction = 'in' for update;
  if not found then raise exception 'LEDGER: jo''natma topilmadi' using errcode = 'P0001'; end if;
  if sh.status <> 'awaiting' then raise exception 'LEDGER: jo''natma allaqachon qabul qilingan yoki rad etilgan' using errcode = 'P0001'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) <> jsonb_array_length(sh.items) then
    raise exception 'LEDGER: har bir qator uchun qabul qilingan son kerak' using errcode = 'P0001';
  end if;
  for v_e in select e from jsonb_array_elements(p_lines) e order by public._fw_num(e->>'idx') loop
    v_idx := public._fw_num(v_e->>'idx')::int;
    if v_idx < 0 or v_idx >= jsonb_array_length(sh.items) or v_idx = any(v_seen) then
      raise exception 'LEDGER: qator raqami noto''g''ri' using errcode = 'P0001';
    end if;
    v_seen := v_seen || v_idx;
    v_it := sh.items->v_idx;
    v_rq := public._fw_num(v_e->>'receivedQty');
    if v_rq < 0 or v_rq > public._fw_num(v_it->>'qty') + 0.000001 then
      raise exception 'LEDGER: qabul qilingan son jo''natilgandan ko''p bo''lishi mumkin emas (%)', left(v_it->>'name', 80) using errcode = 'P0001';
    end if;
    v_price := public._fw_num(v_it->>'priceUsd');
    if v_rq > 0 then
      v_pid := public._fw_num(v_e->>'localPid')::bigint;
      if v_pid is null or v_pid <= 0 then raise exception 'LEDGER: mahsulot moslashtirilmagan (%)', left(v_it->>'name', 80) using errcode = 'P0001'; end if;
      v_b := public._batch_insert(p_filial, v_e->>'batchLocalId', v_pid, v_rq, v_price, 'active',
               jsonb_build_object('origin', left('B2B — ' || coalesce(l.peer_name, 'hamkor'), 300), 'suppId', l.supplier_local_id::text,
                                  'bno', left(p_meta->>'bno', 20), 'date', p_meta->>'date', 'performedBy', p_staff_name),
               'b2b_in', v_key || ':' || v_idx, v_key, 'b2b_receive', p_ship_uid, p_staff_id, p_staff_name);
      v_batches := v_batches || v_b.id;
      v_total := v_total + v_rq * v_price;
      if coalesce(v_it->>'peerPid', '') ~ '^[0-9]{1,18}$' then
        insert into public.b2b_product_map (link_id, peer_pid, local_pid, peer_sku)
        values (l.id, (v_it->>'peerPid')::bigint, v_pid, left(v_it->>'sku', 80))
        on conflict (link_id, peer_pid) do update set local_pid = excluded.local_pid, peer_sku = excluded.peer_sku, updated_at = now();
      end if;
    end if;
    v_out := v_out || (v_it || jsonb_build_object('receivedQty', v_rq, 'localPid', nullif(public._fw_num(v_e->>'localPid'), 0)));
  end loop;
  if v_total > 0 then
    perform public._supp_debt_move(p_filial, l.supplier_local_id, round(v_total, 4), 0, 'strict', 'b2b_receive', v_key || ':debt', v_key,
                                   'b2b_receive', p_ship_uid, left('B2B qabul: ' || coalesce(l.peer_name, ''), 500), p_staff_id, p_staff_name);
  end if;
  update public.b2b_shipments set status = 'received', items = v_out, received_total_usd = round(v_total, 4), received_at = now(), updated_at = now()
   where id = sh.id;
  if sh.order_uid is not null then
    update public.b2b_orders set status = 'closed', updated_at = now() where link_id = l.id and order_uid = sh.order_uid and direction = 'out';
  end if;
  return public._ledger_op_finish(p_filial, p_op_key, 'b2b_receive',
    jsonb_build_object('ok', true, 'kind', 'b2b_receive', 'shipUid', p_ship_uid, 'receivedTotalUsd', round(v_total, 4), 'items', v_out),
    '{}', array[l.supplier_local_id], v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 6. B2B: tasdiq (ta'minotchi tomoni) — xaridor qarzi faqat qabul qilingan son bo'yicha ─
-- p_lines: [{idx, receivedQty}]; p_rate — so'm kursi (mijoz qarzi so'mda yuritiladi)
create or replace function public.b2b_ack_apply(
  p_filial text, p_op_key text, p_link_id bigint, p_ship_uid text, p_lines jsonb, p_rate numeric)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  l public.b2b_links;
  sh public.b2b_shipments;
  v_key text := 'b2a:' || p_op_key;
  v_e jsonb;
  v_it jsonb;
  v_idx int;
  v_rq numeric;
  v_total numeric := 0;
  v_out jsonb;
  v_debt numeric;
  v_custs bigint[] := '{}';
begin
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'b2b_ack');
  if v_prev is not null then return v_prev; end if;
  select * into l from public.b2b_links where id = p_link_id for update;
  if not found or l.status = 'revoked' then raise exception 'LEDGER: B2B ulanish topilmadi' using errcode = 'P0001'; end if;
  select * into sh from public.b2b_shipments where link_id = l.id and ship_uid = p_ship_uid and direction = 'out' for update;
  if not found then raise exception 'LEDGER: jo''natma topilmadi' using errcode = 'P0001'; end if;
  if sh.status <> 'sent' then raise exception 'LEDGER: jo''natma allaqachon tasdiqlangan' using errcode = 'P0001'; end if;
  if p_rate is null or p_rate <= 0 or p_rate > 1000000 then raise exception 'LEDGER: kurs noto''g''ri' using errcode = 'P0001'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) <> jsonb_array_length(sh.items) then
    raise exception 'LEDGER: tasdiq qatorlari noto''g''ri' using errcode = 'P0001';
  end if;
  v_out := sh.items;
  for v_e in select e from jsonb_array_elements(p_lines) e loop
    v_idx := public._fw_num(v_e->>'idx')::int;
    if v_idx < 0 or v_idx >= jsonb_array_length(sh.items) then raise exception 'LEDGER: qator raqami noto''g''ri' using errcode = 'P0001'; end if;
    v_it := sh.items->v_idx;
    v_rq := public._fw_num(v_e->>'receivedQty');
    if v_rq < 0 or v_rq > public._fw_num(v_it->>'qty') + 0.000001 then raise exception 'LEDGER: tasdiqlangan son noto''g''ri' using errcode = 'P0001'; end if;
    v_total := v_total + v_rq * public._fw_num(v_it->>'priceUsd');
    v_out := jsonb_set(v_out, array[v_idx::text], v_it || jsonb_build_object('receivedQty', v_rq));
  end loop;
  if v_total > 0 and l.customer_local_id is not null then
    v_debt := public._cust_debt_move(p_filial, l.customer_local_id, round(v_total * p_rate, 2), 'strict', 'b2b_ship', v_key || ':debt', v_key,
                                     'b2b_ship', p_ship_uid, left('B2B jo''natma: ' || coalesce(l.peer_name, ''), 500), null, 'B2B');
    v_custs := array[l.customer_local_id];
  end if;
  update public.b2b_shipments set status = 'acked', items = v_out, received_total_usd = round(v_total, 4), rate_uzs = p_rate,
         received_at = now(), updated_at = now()
   where id = sh.id;
  return public._ledger_op_finish(p_filial, p_op_key, 'b2b_ack',
    jsonb_build_object('ok', true, 'kind', 'b2b_ack', 'shipUid', p_ship_uid, 'receivedTotalUsd', round(v_total, 4)),
    v_custs, '{}', '{}', null, 'B2B');
end;
$$;

-- ── 7. B2B: kelmay qolgan qismni ta'minotchi omboriga qaytarish ──────────
-- Faqat tasdiqlangan (acked) jo'natma; har qator: (jo'natilgan − qabul qilingan) — FIFO bo'yicha
-- oxirgi olingan partiyalarga qaytariladi; konsignatsiya qarzi mutanosib teskari yoziladi.
create or replace function public.b2b_restock_atomic(
  p_filial text, p_op_key text, p_link_id bigint, p_ship_uid text, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  sh public.b2b_shipments;
  v_key text := 'b2x:' || p_op_key;
  v_it jsonb;
  v_a jsonb;
  v_diff numeric;
  v_take numeric;
  v_n int := 0;
  v_batches bigint[] := '{}';
  v_supps bigint[] := '{}';
  v_units numeric := 0;
  r record;
  v_side jsonb := '[]'::jsonb;
begin
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'b2b_restock');
  if v_prev is not null then return v_prev; end if;
  select * into sh from public.b2b_shipments where link_id = p_link_id and ship_uid = p_ship_uid and direction = 'out' and filial = p_filial for update;
  if not found then raise exception 'LEDGER: jo''natma topilmadi' using errcode = 'P0001'; end if;
  if sh.status <> 'acked' then raise exception 'LEDGER: faqat tasdiqlangan jo''natmaning farqini qaytarish mumkin' using errcode = 'P0001'; end if;
  for v_it in select * from jsonb_array_elements(sh.items) loop
    v_diff := public._fw_num(v_it->>'qty') - public._fw_num(v_it->>'receivedQty');
    continue when v_diff <= 0.000001;
    v_units := v_units + v_diff;
    -- konsignatsiya qarzi: shu qatordagi ulushga mutanosib
    if jsonb_typeof(v_it->'side') = 'array' and public._fw_num(v_it->>'qty') > 0 then
      select v_side || coalesce(jsonb_agg(jsonb_build_object('supp', e->>'supp', 'usd', public._fw_num(e->>'usd') * v_diff / public._fw_num(v_it->>'qty')))
        , '[]'::jsonb) into v_side from jsonb_array_elements(v_it->'side') e;
    end if;
    for v_a in select t.value from jsonb_array_elements(coalesce(v_it->'allocs', '[]'::jsonb)) with ordinality t(value, o) order by t.o desc loop
      exit when v_diff <= 0.000001;
      v_take := least(public._fw_num(v_a->>'take'), v_diff);
      v_n := v_n + 1;
      perform public._stock_move((v_a->>'batchId')::bigint, 0, -v_take, 'b2b_restock', v_key || ':' || v_n, v_key, 'b2b_ship', sh.ship_uid,
                                 'B2B: kelmay qolgan qism omborga qaytdi', p_staff_id, p_staff_name);
      v_batches := v_batches || (v_a->>'batchId')::bigint;
      v_diff := v_diff - v_take;
    end loop;
  end loop;
  if v_units <= 0 then raise exception 'LEDGER: qaytariladigan farq yo''q' using errcode = 'P0001'; end if;
  for r in select (e->>'supp')::bigint as supp, sum(public._fw_num(e->>'usd')) as usd from jsonb_array_elements(v_side) e group by 1 order by 1 loop
    continue when r.usd = 0;
    perform public._supp_debt_move(p_filial, r.supp, -round(r.usd, 4), 0, 'strict', 'b2b_restock', v_key || ':s:' || r.supp, v_key, 'b2b_ship', sh.ship_uid,
                                   'B2B: qaytgan qism (konsignatsiya)', p_staff_id, p_staff_name);
    v_supps := v_supps || r.supp;
  end loop;
  update public.b2b_shipments set status = 'restocked', updated_at = now() where id = sh.id;
  return public._ledger_op_finish(p_filial, p_op_key, 'b2b_restock',
    jsonb_build_object('ok', true, 'kind', 'b2b_restock', 'shipUid', sh.ship_uid, 'units', v_units),
    '{}', v_supps, v_batches, p_staff_id, p_staff_name);
end;
$$;

-- ── 8. Huquqlar ────────────────────────────────────────────────────────
revoke all on function public.stock_writeoff_atomic(text, text, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.stock_writeoff_cancel(text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.b2b_ship_atomic(text, text, bigint, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.b2b_receive_atomic(text, text, bigint, text, jsonb, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.b2b_ack_apply(text, text, bigint, text, jsonb, numeric) from public, anon, authenticated;
revoke all on function public.b2b_restock_atomic(text, text, bigint, text, bigint, text) from public, anon, authenticated;
grant execute on function public.stock_writeoff_atomic(text, text, jsonb, bigint, text) to service_role;
grant execute on function public.stock_writeoff_cancel(text, text, text, text, bigint, text) to service_role;
grant execute on function public.b2b_ship_atomic(text, text, bigint, jsonb, bigint, text) to service_role;
grant execute on function public.b2b_receive_atomic(text, text, bigint, text, jsonb, jsonb, bigint, text) to service_role;
grant execute on function public.b2b_ack_apply(text, text, bigint, text, jsonb, numeric) to service_role;
grant execute on function public.b2b_restock_atomic(text, text, bigint, text, bigint, text) to service_role;

-- Ruxsat kalitlari (owner/administrator — barchasi; ombor mudiri — hisobdan chiqarish)
do $$ begin
  if to_regclass('public.permissions') is not null then
    insert into public.permissions (key, module, label) values
      ('ombor.writeoff', 'ombor', 'Tovarni hisobdan chiqarish (buzilgan, muddati o''tgan, singan)'),
      ('b2b.view', 'b2b', 'B2B hamkorlarni, buyurtma va jo''natmalarni ko''rish'),
      ('b2b.order', 'b2b', 'B2B hamkordan buyurtma berish va kelgan tovarni qabul qilish'),
      ('b2b.ship', 'b2b', 'B2B hamkor buyurtmasini tasdiqlash va jo''natish')
    on conflict (key) do nothing;
    if to_regclass('public.role_permissions') is not null and to_regclass('public.roles') is not null then
      insert into public.role_permissions (role_id, permission_id)
        select r.id, p.id from public.roles r join public.permissions p on p.key in ('ombor.writeoff', 'b2b.view', 'b2b.order', 'b2b.ship')
        where r.key in ('owner', 'administrator')
      on conflict do nothing;
      insert into public.role_permissions (role_id, permission_id)
        select r.id, p.id from public.roles r join public.permissions p on p.key = 'ombor.writeoff'
        where r.key = 'warehouse_manager'
      on conflict do nothing;
    end if;
  end if;
end $$;

-- ────────────────────────────────────────────────────────────────────
-- 14. 30-migratsiya: DILLER PUL YUBORADI — to'lov xabarnomasi (qarz darhol kamayadi, kassir qabul qiladi yoki rad etadi)
-- (supabase-migration-30-diller-tolov-xabarnomasi.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 30-MIGRATSIYA (v23.8): DILLER PUL YUBORADI — TO'LOV XABARNOMASI (egasi tasdiqlagan qoida, 2026-10-07)
--   • Diller o'z portalidan pul yuboradi: naqd so'm, karta (so'm) yoki naqd dollar.
--     So'm summa SHU KUNGI KURS (serverdagi settings.usdUzs) bo'yicha dollarga o'giriladi va kurs xabarnomada qotiriladi.
--   • Diller qarzi DARHOL kamayadi (dealer_payments + dealers, bitta tranzaksiya).
--   • Bosh kassa / kassirga bildirishnoma ("kutilmoqda"):
--       «Qabul qildim» — pul tanlangan filial kassasiga tushadi (odatda Diller kassasi; so'm — so'm kassasiga),
--                        kassa yopishda boshqa pul bilan birga Bosh kassaga topshiriladi;
--       «Rad etish»    — pul kelmagan: diller qarzi QAYTADI (teskari yozuv, tarix o'chirilmaydi).
-- Faqat qo'shadi; ma'lumot o'chirmaydi; qayta ishga tushirish xavfsiz. Talab: 24 va 25-migratsiyalar (kassa jurnali).
-- Jadval faqat service_role (server funksiyasi `dealer-pay`) uchun — brauzer to'g'ridan-to'g'ri o'qimaydi/yozmaydi.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.cashbox_ledger') is null or not exists (select 1 from pg_proc where proname = 'cashbox_apply_ops')
     or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'dealer_payments' and column_name = 'idem_key') then
    raise exception '30-migratsiya: avval 24 va 25-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Jadval ──────────────────────────────────────────────────────────
create table if not exists public.dealer_pay_notices (
  id bigint generated always as identity primary key,
  dealer_id bigint not null references public.dealers(id) on delete cascade,
  filial text not null default 'baza',
  pay_type text not null,
  currency text not null,
  amount numeric(18,2) not null,
  rate numeric(14,4) not null,
  amount_usd numeric(14,2) not null,
  note text,
  status text not null default 'pending',
  idem_key text not null,
  dealer_payment_id bigint,
  box_local_id integer,
  box_name text,
  decided_at timestamptz,
  decided_by_id bigint,
  decided_by_name text,
  reject_reason text,
  created_at timestamptz not null default now(),
  constraint dealer_pay_notices_type_chk check (pay_type in ('cash_uzs','card','cash_usd')),
  constraint dealer_pay_notices_cur_chk check (currency in ('UZS','USD') and (currency = 'USD') = (pay_type = 'cash_usd')),
  constraint dealer_pay_notices_amt_chk check (amount > 0 and amount_usd > 0 and rate > 0),
  constraint dealer_pay_notices_status_chk check (status in ('pending','accepted','rejected'))
);
create unique index if not exists dealer_pay_notices_idem_uq on public.dealer_pay_notices (idem_key);
create index if not exists dealer_pay_notices_filial_status_idx on public.dealer_pay_notices (filial, status, created_at desc);
create index if not exists dealer_pay_notices_dealer_idx on public.dealer_pay_notices (dealer_id, created_at desc);

alter table public.dealer_pay_notices enable row level security;
revoke all on public.dealer_pay_notices from public, anon, authenticated;
grant select, insert, update on public.dealer_pay_notices to service_role;

-- ── 2. Yuborish: qarz darhol kamayadi ─────────────────────────────────
-- p_rate — 1$ necha so'm (server settings.usdUzs dan oladi; diller kiritmaydi).
create or replace function public.dealer_pay_notice_create(
  p_dealer_id bigint, p_pay_type text, p_amount numeric, p_rate numeric, p_note text, p_idem text)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_d record;
  v_n public.dealer_pay_notices;
  v_cur text;
  v_amt numeric;
  v_usd numeric;
  v_pay bigint;
begin
  if coalesce(p_idem, '') !~ '^[A-Za-z0-9_-]{8,80}$' then raise exception 'DEALER_PAY: amal kaliti noto''g''ri' using errcode = 'P0001'; end if;
  if p_pay_type is null or p_pay_type not in ('cash_uzs','card','cash_usd') then raise exception 'DEALER_PAY: to''lov turi noto''g''ri' using errcode = 'P0001'; end if;
  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 100000000000 then raise exception 'DEALER_PAY: summa noto''g''ri' using errcode = 'P0001'; end if;
  if p_rate is null or p_rate = 'NaN'::numeric or p_rate < 100 or p_rate > 1000000 then raise exception 'DEALER_PAY: kurs belgilanmagan — administratorga murojaat qiling' using errcode = 'P0001'; end if;

  perform pg_advisory_xact_lock(hashtext('dpn:' || p_idem));
  select * into v_n from public.dealer_pay_notices where idem_key = p_idem;
  if found then
    if v_n.dealer_id <> p_dealer_id or v_n.pay_type <> p_pay_type or v_n.amount <> round(p_amount, 2) then
      raise exception 'DEALER_PAY: amal kaliti boshqa to''lov uchun ishlatilgan' using errcode = 'P0001';
    end if;
    select debt_usd, total_paid_usd into v_d from public.dealers where id = p_dealer_id;
    return jsonb_build_object('ok', true, 'replay', true, 'notice', to_jsonb(v_n), 'dealerDebtUsd', v_d.debt_usd, 'dealerTotalPaidUsd', v_d.total_paid_usd);
  end if;

  select id, name, filial, debt_usd, total_paid_usd into v_d from public.dealers where id = p_dealer_id for update;
  if not found then raise exception 'DEALER_PAY: diller topilmadi' using errcode = 'P0001'; end if;

  v_cur := case when p_pay_type = 'cash_usd' then 'USD' else 'UZS' end;
  v_amt := round(p_amount, 2);
  v_usd := case when v_cur = 'USD' then v_amt else round(v_amt / p_rate, 2) end;
  if v_usd <= 0 then raise exception 'DEALER_PAY: summa juda kichik' using errcode = 'P0001'; end if;
  if v_usd > coalesce(v_d.debt_usd, 0) + 0.01 then
    raise exception 'DEALER_PAY: to''lov (% $) qarzingizdan (% $) oshib ketdi', v_usd, coalesce(v_d.debt_usd, 0) using errcode = 'P0001';
  end if;

  insert into public.dealer_payments (dealer_id, amount_usd, note, idem_key)
  values (v_d.id, v_usd, left('Portal: ' || case p_pay_type when 'cash_uzs' then 'naqd so''m' when 'card' then 'karta' else 'naqd $' end
           || case when v_cur = 'UZS' then ' ' || v_amt::text || ' so''m, kurs ' || round(p_rate, 2)::text else '' end
           || coalesce(' — ' || nullif(btrim(p_note), ''), ''), 300), 'dpn:' || p_idem)
  returning id into v_pay;
  update public.dealers set debt_usd = greatest(round(coalesce(debt_usd, 0) - v_usd, 2), 0), total_paid_usd = coalesce(total_paid_usd, 0) + v_usd
   where id = v_d.id returning debt_usd, total_paid_usd into v_d.debt_usd, v_d.total_paid_usd;

  insert into public.dealer_pay_notices (dealer_id, filial, pay_type, currency, amount, rate, amount_usd, note, idem_key, dealer_payment_id)
  values (v_d.id, coalesce(v_d.filial, 'baza'), p_pay_type, v_cur, v_amt, round(p_rate, 4), v_usd, left(nullif(btrim(p_note), ''), 300), p_idem, v_pay)
  returning * into v_n;
  return jsonb_build_object('ok', true, 'replay', false, 'notice', to_jsonb(v_n), 'dealerDebtUsd', v_d.debt_usd, 'dealerTotalPaidUsd', v_d.total_paid_usd);
end;
$$;

-- ── 3. Qabul qildim: pul filial kassasiga (kassa jurnali bilan bitta tranzaksiyada) ──
create or replace function public.dealer_pay_notice_accept(
  p_id bigint, p_filial text, p_box integer, p_box_name text, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_n public.dealer_pay_notices;
  v_dname text;
  v_res jsonb;
begin
  select * into v_n from public.dealer_pay_notices where id = p_id for update;
  if not found then raise exception 'DEALER_PAY: xabarnoma topilmadi' using errcode = 'P0001'; end if;
  if v_n.filial <> p_filial then raise exception 'DEALER_PAY: xabarnoma boshqa filialga tegishli' using errcode = 'P0001'; end if;
  if v_n.status = 'rejected' then raise exception 'DEALER_PAY: xabarnoma rad etilgan' using errcode = 'P0001'; end if;
  if v_n.status = 'accepted' then
    if v_n.box_local_id is distinct from p_box then raise exception 'DEALER_PAY: xabarnoma boshqa kassaga qabul qilingan' using errcode = 'P0001'; end if;
    return jsonb_build_object('ok', true, 'replay', true, 'notice', to_jsonb(v_n), 'balances', public._cb_balances_map(p_filial, array[p_box]));
  end if;
  select name into v_dname from public.dealers where id = v_n.dealer_id;
  v_res := public.cashbox_apply_ops(p_filial, 'dpn:' || v_n.id, 'dealer_pay',
    jsonb_build_array(jsonb_build_object('box', p_box, 'dir', 'in', 'amount', v_n.amount, 'currency', v_n.currency, 'box_name', p_box_name,
      'ref_type', 'dealer', 'ref_id', v_n.dealer_id::text,
      'note', left('Diller to''lovi (portal) — ' || coalesce(v_dname, '') || case when v_n.currency = 'UZS' then ', kurs ' || round(v_n.rate, 2)::text else '' end, 500))),
    p_staff_id, p_staff_name);
  update public.dealer_pay_notices set status = 'accepted', box_local_id = p_box, box_name = left(p_box_name, 200),
         decided_at = now(), decided_by_id = p_staff_id, decided_by_name = left(p_staff_name, 200)
   where id = v_n.id returning * into v_n;
  return jsonb_build_object('ok', true, 'replay', false, 'notice', to_jsonb(v_n), 'balances', v_res->'balances');
end;
$$;

-- ── 4. Rad etish: pul kelmagan — diller qarzi qaytadi (teskari yozuv) ──
create or replace function public.dealer_pay_notice_reject(
  p_id bigint, p_filial text, p_reason text, p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_n public.dealer_pay_notices;
  v_d record;
begin
  if length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'DEALER_PAY: rad etish sababini yozing' using errcode = 'P0001'; end if;
  select * into v_n from public.dealer_pay_notices where id = p_id for update;
  if not found then raise exception 'DEALER_PAY: xabarnoma topilmadi' using errcode = 'P0001'; end if;
  if v_n.filial <> p_filial then raise exception 'DEALER_PAY: xabarnoma boshqa filialga tegishli' using errcode = 'P0001'; end if;
  if v_n.status = 'accepted' then raise exception 'DEALER_PAY: pul kassaga qabul qilingan — rad etib bo''lmaydi' using errcode = 'P0001'; end if;
  if v_n.status = 'rejected' then
    select debt_usd, total_paid_usd into v_d from public.dealers where id = v_n.dealer_id;
    return jsonb_build_object('ok', true, 'replay', true, 'notice', to_jsonb(v_n), 'dealerDebtUsd', v_d.debt_usd, 'dealerTotalPaidUsd', v_d.total_paid_usd);
  end if;
  select id, debt_usd, total_paid_usd into v_d from public.dealers where id = v_n.dealer_id for update;
  insert into public.dealer_payments (dealer_id, amount_usd, note, idem_key)
  values (v_n.dealer_id, -v_n.amount_usd, left('Rad etildi (pul kelmadi): ' || btrim(p_reason), 300), 'dpnr:' || v_n.id);
  update public.dealers set debt_usd = round(coalesce(debt_usd, 0) + v_n.amount_usd, 2), total_paid_usd = greatest(round(coalesce(total_paid_usd, 0) - v_n.amount_usd, 2), 0)
   where id = v_n.dealer_id returning debt_usd, total_paid_usd into v_d.debt_usd, v_d.total_paid_usd;
  update public.dealer_pay_notices set status = 'rejected', reject_reason = left(btrim(p_reason), 300),
         decided_at = now(), decided_by_id = p_staff_id, decided_by_name = left(p_staff_name, 200)
   where id = v_n.id returning * into v_n;
  return jsonb_build_object('ok', true, 'replay', false, 'notice', to_jsonb(v_n), 'dealerDebtUsd', v_d.debt_usd, 'dealerTotalPaidUsd', v_d.total_paid_usd);
end;
$$;

revoke all on function public.dealer_pay_notice_create(bigint, text, numeric, numeric, text, text) from public, anon, authenticated;
revoke all on function public.dealer_pay_notice_accept(bigint, text, integer, text, bigint, text) from public, anon, authenticated;
revoke all on function public.dealer_pay_notice_reject(bigint, text, text, bigint, text) from public, anon, authenticated;
grant execute on function public.dealer_pay_notice_create(bigint, text, numeric, numeric, text, text) to service_role;
grant execute on function public.dealer_pay_notice_accept(bigint, text, integer, text, bigint, text) to service_role;
grant execute on function public.dealer_pay_notice_reject(bigint, text, text, bigint, text) to service_role;

-- ────────────────────────────────────────────────────────────────────
-- 15. 31-migratsiya: TAHRIRLASH MUDDATLARI, AUDIT TARIXI, BILDIRISHNOMALAR, ZARAR TASDIG'I, DILLER CHEGIRMA CHEGARASI, DIRECT SALE RUXSATI
-- (supabase-migration-31-tahrir-muddati-audit-bildirishnoma.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 31-MIGRATSIYA (v24): TAHRIRLASH MUDDATLARI, AUDIT TARIXI, BILDIRISHNOMALAR,
--                      ZARARLI SAVDO TASDIG'I, DILLER NARX CHEGARASI, DIRECT SALE RUXSATI
-- Egasi tasdiqlagan qoidalar (2026-10-11):
--   • Tahrirlash muddati — yozuv yaratilgan vaqtdan (SERVER vaqti): administrator 30 kun, sotuvchi 7 kun, diller 4 kun.
--     Sotuvchi faqat o'zi bajargan savdoni (yoki «savdo.edit» ruxsati bo'lsa — boshqalarnikini ham) tahrirlaydi.
--     Har tahrir/o'chirishda oldingi va yangi qiymat, kim, roli, vaqti — o'zgarmas audit jurnaliga yoziladi.
--   • Tannarxdan past (zarar bilan) savdo: sotuvchi O'ZI tasdiqlaydi (tannarx unga ko'rsatilmaydi); tasdiqsiz server rad etadi;
--     tasdiqlangan zararli savdo auditga yoziladi va administratorga bildirishnoma boradi.
--   • Bildirishnomalar — alohida jadval; 7 kundan eskilari «arxiv» (o'chirilmaydi). Moliyaviy yozuvlarga tegilmaydi.
--   • Diller: joriy optom narxidan ko'pi bilan 10% chegirma (server rad etadi); chegirmali savdo auditda.
--   • «savdo.direct_sale» ruxsati — omborda yo'q Direct Sale mahsulotini sotish. Hozir savdo qila oladigan rollarga
--     (oddiy «Xodim» — employee va diller bundan mustasno) beriladi — mavjud xatti-harakat buzilmaydi.
-- Faqat qo'shadi; mavjud ma'lumot o'chirilmaydi/o'zgartirilmaydi; qayta ishga tushirish xavfsiz.
-- Talab: 27-migratsiya (savdo hujjati serverda, ledger_ops) va 23-migratsiya (record_dealer_sale).
-- Yangi jadvallar faqat service_role (server funksiyalari) uchun — brauzer to'g'ridan-to'g'ri o'qimaydi/yozmaydi.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.ledger_ops') is null or not exists (select 1 from pg_proc where proname = 'sale_edit_atomic')
     or not exists (select 1 from pg_proc where proname = 'sale_checkout_atomic_v3') then
    raise exception '31-migratsiya: avval 27-migratsiyani qo''llang';
  end if;
end $$;

-- ── 1. AUDIT JURNALI (o'zgarmas) ───────────────────────────────────────
create table if not exists public.fw_audit_events (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text,
  entity text not null,
  entity_id text,
  action text not null,
  actor_id bigint,
  actor_name text,
  actor_role text not null default 'system',
  before jsonb,
  after jsonb,
  note text,
  op_key text,
  constraint fw_audit_events_role_chk check (actor_role in ('admin','seller','dealer','system')),
  constraint fw_audit_events_action_chk check (action in ('create','edit','void','loss_sale','price_discount','revision','announce')),
  constraint fw_audit_events_len_chk check (length(entity) <= 40 and coalesce(length(entity_id),0) <= 80 and coalesce(length(actor_name),0) <= 200
    and coalesce(length(note),0) <= 1000 and coalesce(length(op_key),0) <= 160 and coalesce(length(filial),0) <= 40)
);
create index if not exists idx_fw_audit_entity on public.fw_audit_events (entity, entity_id, created_at desc);
create index if not exists idx_fw_audit_filial on public.fw_audit_events (filial, created_at desc);
create unique index if not exists fw_audit_events_op_uq on public.fw_audit_events (op_key, action) where op_key is not null;

create or replace function public._fw_audit_immutable()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  raise exception 'AUDIT: audit yozuvini o''zgartirib yoki o''chirib bo''lmaydi' using errcode = 'P0001';
end;
$$;
create or replace trigger fw_audit_events_immutable before update or delete on public.fw_audit_events
  for each row execute function public._fw_audit_immutable();
create or replace trigger fw_audit_events_no_truncate before truncate on public.fw_audit_events
  for each statement execute function public._fw_audit_immutable();

alter table public.fw_audit_events enable row level security;
revoke all on public.fw_audit_events from anon, authenticated;
grant select, insert on public.fw_audit_events to service_role;
grant usage on sequence public.fw_audit_events_id_seq to service_role;

-- ── 2. BILDIRISHNOMALAR (7 kundan keyin — arxiv; o'chirilmaydi) ───────
create table if not exists public.fw_notifications (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text,
  audience text not null,
  audience_id bigint,
  kind text not null,
  title text not null,
  body text,
  ref_type text,
  ref_id text,
  actor_name text,
  actor_role text,
  dedupe_key text,
  read_at timestamp with time zone,
  constraint fw_notifications_audience_chk check (audience in ('admin','seller','dealer')),
  constraint fw_notifications_kind_chk check (kind in ('sale_edit','sale_void','loss_sale','dealer_discount','dealer_revision','dealer_pay','announce_error','system')),
  constraint fw_notifications_len_chk check (length(title) <= 200 and coalesce(length(body),0) <= 1000 and coalesce(length(ref_id),0) <= 80
    and coalesce(length(dedupe_key),0) <= 200 and coalesce(length(actor_name),0) <= 200 and coalesce(length(filial),0) <= 40)
);
create index if not exists idx_fw_notif_aud on public.fw_notifications (audience, filial, created_at desc);
create unique index if not exists fw_notifications_dedupe_uq on public.fw_notifications (dedupe_key) where dedupe_key is not null;

-- Faqat «o'qildi» belgisi o'zgaradi; mazmun o'zgarmaydi va yozuv o'chirilmaydi (arxiv — yoshi bo'yicha)
create or replace function public._fw_notif_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'NOTIF: bildirishnomani o''chirib bo''lmaydi (7 kundan keyin arxivga o''tadi)' using errcode = 'P0001';
  end if;
  if (to_jsonb(new) - 'read_at') <> (to_jsonb(old) - 'read_at') then
    raise exception 'NOTIF: faqat «o''qildi» belgisini o''zgartirish mumkin' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create or replace trigger fw_notifications_guard before update or delete on public.fw_notifications
  for each row execute function public._fw_notif_guard();

alter table public.fw_notifications enable row level security;
revoke all on public.fw_notifications from anon, authenticated;
grant select, insert on public.fw_notifications to service_role;
grant update (read_at) on public.fw_notifications to service_role;
grant usage on sequence public.fw_notifications_id_seq to service_role;

-- ── 3. TAHRIRLASH MUDDATI (server vaqti) ───────────────────────────────
create or replace function public.fw_edit_window_days(p_role text)
 returns integer
 language sql
 immutable
 set search_path = ''
as $$
  select case p_role when 'admin' then 30 when 'seller' then 7 when 'dealer' then 4 else 0 end;
$$;

-- Yozuv yaratilgan vaqt: bazadagi created_at va savdo sanasi (Toshkent kuni boshi) — qaysi biri ERTAROQ bo'lsa
-- (eski, ko'chirib yozilgan savdolar created_at'i migratsiya kuni bo'lib qolgani uchun — qat'iyroq tomon)
create or replace function public.fw_sale_created_at(s public.sales)
 returns timestamp with time zone
 language sql
 stable
 set search_path = ''
as $$
  select least(s.created_at, coalesce((s.sale_date::timestamp at time zone 'Asia/Tashkent'), s.created_at));
$$;

create or replace function public._fw_assert_sale_edit(s public.sales, p_role text, p_staff_id bigint, p_can_others boolean)
 returns void
 language plpgsql
 stable
 set search_path = ''
as $$
declare
  v_days integer := public.fw_edit_window_days(p_role);
  v_created timestamptz := public.fw_sale_created_at(s);
begin
  if p_role not in ('admin','seller') then
    raise exception 'TAHRIR: bu rol savdoni tahrirlay olmaydi' using errcode = 'P0001';
  end if;
  if s.is_transfer then
    raise exception 'TAHRIR: filiallararo o''tkazma savdosi bu yerda tahrirlanmaydi' using errcode = 'P0001';
  end if;
  if p_role = 'seller' and not coalesce(p_can_others, false) and s.staff_id is distinct from p_staff_id then
    raise exception 'TAHRIR: faqat o''zingiz bajargan savdoni tahrirlay olasiz' using errcode = 'P0001';
  end if;
  if now() > v_created + make_interval(days => v_days) then
    raise exception 'TAHRIR: tahrirlash muddati tugagan (% kun; savdo % da yaratilgan) — administrator tuzatish yozuvi bilan o''zgartiradi',
      v_days, to_char(v_created at time zone 'Asia/Tashkent', 'DD.MM.YYYY HH24:MI') using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public._fw_sale_snapshot(p_id bigint)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select public._fw_sale_json(s) || jsonb_build_object('staffId', s.staff_id, 'staffName', s.staff_name, 'createdAt', s.created_at,
    'editedAt', s.edited_at, 'voidedAt', s.voided_at, 'payType', s.pay_type, 'custName', s.cust_name)
  from public.sales s where s.id = p_id;
$$;

-- ── 4. SAVDONI TAHRIRLASH / O'CHIRISH — muddat + audit + bildirishnoma (bitta tranzaksiya) ──
create or replace function public.sale_edit_guarded(
  p_filial text, p_op_key text, p_sale_local_id text, p_mode text, p_payload jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_can_others boolean default false)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  s public.sales;
  v_before jsonb;
  v_res jsonb;
begin
  -- Takroriy so'rov (tarmoq uzilgan) — avvalgi natija qaytadi, muddat qayta tekshirilmaydi
  if exists (select 1 from public.ledger_ops where filial = p_filial and op_key = p_op_key) then
    return public.sale_edit_atomic(p_filial, p_op_key, p_sale_local_id, p_mode, p_payload, p_staff_id, p_staff_name);
  end if;
  select * into s from public.sales where filial = p_filial and local_id = p_sale_local_id for update;
  if not found then
    raise exception 'LEDGER: savdo serverda topilmadi' using errcode = 'P0001';
  end if;
  perform public._fw_assert_sale_edit(s, p_role, p_staff_id, p_can_others);
  v_before := public._fw_sale_snapshot(s.id);
  v_res := public.sale_edit_atomic(p_filial, p_op_key, p_sale_local_id, p_mode, p_payload, p_staff_id, p_staff_name);
  insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
  values (p_filial, 'sale', s.local_id, 'edit', p_staff_id, left(p_staff_name, 200), p_role, v_before, public._fw_sale_snapshot(s.id),
          left('Tahrir (' || p_mode || '): ' || s.inv, 1000), p_op_key)
  on conflict do nothing;
  if p_role <> 'admin' then
    insert into public.fw_notifications (filial, audience, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
    values (p_filial, 'admin', 'sale_edit', left('Savdo tahrirlandi: ' || s.inv, 200),
            left(coalesce(p_staff_name, 'Xodim') || ' savdoni tahrirladi: ' || round(s.total_usd, 2) || ' $ → '
                 || coalesce(round((select total_usd from public.sales where id = s.id), 2)::text, '?') || ' $', 1000),
            'sale', s.local_id, left(p_staff_name, 200), p_role, 'sale_edit:' || p_filial || ':' || p_op_key)
    on conflict do nothing;
  elsif s.staff_id is not null and s.staff_id is distinct from p_staff_id then
    -- Administrator sotuvchining savdosini tuzatdi — sotuvchiga bildirishnoma
    insert into public.fw_notifications (filial, audience, audience_id, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
    values (p_filial, 'seller', s.staff_id, 'sale_edit', left('Savdongiz tuzatildi: ' || s.inv, 200),
            left('Administrator (' || coalesce(p_staff_name, 'Admin') || ') savdoni tahrirladi.', 1000),
            'sale', s.local_id, left(p_staff_name, 200), p_role, 'sale_edit_s:' || p_filial || ':' || p_op_key)
    on conflict do nothing;
  end if;
  return v_res;
end;
$$;

create or replace function public.sale_void_guarded(
  p_filial text, p_op_key text, p_sale_local_id text, p_batch_ids jsonb, p_meta jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_can_others boolean default false)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  s public.sales;
  v_before jsonb;
  v_res jsonb;
begin
  if exists (select 1 from public.ledger_ops where filial = p_filial and op_key = p_op_key) then
    return public.sale_void_atomic(p_filial, p_op_key, p_sale_local_id, p_batch_ids, p_meta, p_staff_id, p_staff_name);
  end if;
  select * into s from public.sales where filial = p_filial and local_id = p_sale_local_id for update;
  if not found then
    raise exception 'LEDGER: savdo serverda topilmadi' using errcode = 'P0001';
  end if;
  perform public._fw_assert_sale_edit(s, p_role, p_staff_id, p_can_others);
  v_before := public._fw_sale_snapshot(s.id);
  v_res := public.sale_void_atomic(p_filial, p_op_key, p_sale_local_id, p_batch_ids, p_meta, p_staff_id, p_staff_name);
  -- Savdo yozuvi bazada QOLADI (status='voided') — bu yerda faqat iz va kim/qachon
  insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
  values (p_filial, 'sale', s.local_id, 'void', p_staff_id, left(p_staff_name, 200), p_role, v_before, public._fw_sale_snapshot(s.id),
          left('O''chirildi (teskari yozuv): ' || s.inv, 1000), p_op_key)
  on conflict do nothing;
  if p_role <> 'admin' then
    insert into public.fw_notifications (filial, audience, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
    values (p_filial, 'admin', 'sale_void', left('Savdo oʻchirildi: ' || s.inv, 200),
            left(coalesce(p_staff_name, 'Xodim') || ' savdoni o''chirdi (' || round(s.total_usd, 2) || ' $). Ombor, kassa va qarz teskari qaytarildi.', 1000),
            'sale', s.local_id, left(p_staff_name, 200), p_role, 'sale_void:' || p_filial || ':' || p_op_key)
    on conflict do nothing;
  elsif s.staff_id is not null and s.staff_id is distinct from p_staff_id then
    insert into public.fw_notifications (filial, audience, audience_id, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
    values (p_filial, 'seller', s.staff_id, 'sale_void', left('Savdongiz oʻchirildi: ' || s.inv, 200),
            left('Administrator (' || coalesce(p_staff_name, 'Admin') || ') savdoni o''chirdi (teskari yozuv bilan).', 1000),
            'sale', s.local_id, left(p_staff_name, 200), p_role, 'sale_void_s:' || p_filial || ':' || p_op_key)
    on conflict do nothing;
  end if;
  return v_res;
end;
$$;

-- ── 5. SAVDO YARATISH — zarar tasdig'i + audit (bitta tranzaksiya; rad etilsa hech narsa yozilmaydi) ──
create or replace function public.sale_checkout_guarded(
  p_filial text, p_op_key text, p_sale jsonb, p_box_payments jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_loss_ack boolean default false)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_res jsonb;
  v_total numeric;
  v_cost numeric;
  v_loss numeric;
  v_items jsonb;
begin
  if p_role not in ('admin','seller') then
    raise exception 'SAVDO: rol noto''g''ri' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.ledger_ops where filial = p_filial and op_key = p_op_key) then
    return public.sale_checkout_atomic_v3(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name);
  end if;
  v_res := public.sale_checkout_atomic_v3(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name);
  v_total := coalesce((v_res->>'totalUsd')::numeric, 0);
  v_cost := coalesce((v_res->>'costUsd')::numeric, 0);
  v_loss := round(v_cost - v_total, 2);
  if v_loss > 0.005 and p_role <> 'admin' and not coalesce(p_loss_ack, false) then
    -- Tranzaksiya to'liq bekor bo'ladi (ombor, kassa, qarz, savdo hujjati — hech biri yozilmaydi)
    raise exception 'LOSS_ACK_REQUIRED: savdo tannarxdan past (zarar) — sotuvchi tasdig''i kerak' using errcode = 'P0001';
  end if;
  v_items := coalesce(v_res->'sale'->'items', '[]'::jsonb);
  insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
  values (p_filial, 'sale', v_res->>'localId', 'create', p_staff_id, left(p_staff_name, 200), p_role, null, v_res->'sale',
          left('Savdo: ' || coalesce(v_res->>'inv', ''), 1000), p_op_key)
  on conflict do nothing;
  if v_loss > 0.005 then
    insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
    values (p_filial, 'sale', v_res->>'localId', 'loss_sale', p_staff_id, left(p_staff_name, 200), p_role, null,
            jsonb_build_object('inv', v_res->>'inv', 'totalUsd', v_total, 'costUsd', v_cost, 'lossUsd', v_loss, 'items', v_items,
                               'confirmedBy', p_staff_name, 'confirmedRole', p_role, 'confirmedAt', now()),
            left('Zarar bilan savdo tasdiqlandi: ' || coalesce(v_res->>'inv', '') || ' — zarar ' || v_loss || ' $', 1000), p_op_key)
    on conflict do nothing;
    if p_role <> 'admin' then
      insert into public.fw_notifications (filial, audience, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
      values (p_filial, 'admin', 'loss_sale', left('Zarar bilan savdo: ' || coalesce(v_res->>'inv', ''), 200),
              left(coalesce(p_staff_name, 'Xodim') || ' tannarxdan past sotdi va tasdiqladi. Savdo ' || round(v_total, 2) || ' $, tannarx '
                   || round(v_cost, 2) || ' $, zarar ' || v_loss || ' $.', 1000),
              'sale', v_res->>'localId', left(p_staff_name, 200), p_role, 'loss_sale:' || p_filial || ':' || p_op_key)
      on conflict do nothing;
    end if;
  end if;
  return v_res;
end;
$$;

-- ── 6. DILLER SAVDOSI — optom narxidan ko'pi bilan 10% chegirma (server) ──
-- 23-migratsiyadagi tana o'zgarmagan; faqat chegara tekshiruvi va chegirma auditi qo'shildi.
CREATE OR REPLACE FUNCTION public.record_dealer_sale(p_pid bigint, p_qty numeric, p_sell_usd numeric, p_sku text, p_name text, p_points numeric DEFAULT 0, p_optim_price numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dealer_id bigint;
  v_dealer_name text;
  v_filial text;
  v_stock numeric;
  v_avg numeric;
  v_optim numeric;
  v_floor numeric;
  v_pct numeric;
  v_settings jsonb;
  v_usd_val numeric;
  v_step numeric;
  v_points numeric := 0;
begin
  -- p_points va p_optim_price — orqaga moslik uchun qabul qilinadi, lekin ISHLATILMAYDI:
  -- diller o'z qarzi va ballarini o'zi belgilay olmasligi kerak (v10 audit J3).
  select id, name, filial into v_dealer_id, v_dealer_name, v_filial from dealers where auth_user_id = auth.uid();
  if v_dealer_id is null then
    raise exception 'Diller topilmadi, avval tizimga kiring';
  end if;
  if p_qty is null or p_qty = 'NaN'::numeric or p_qty <= 0 or p_qty > 1000000 then
    raise exception 'Miqdor 0 dan katta bolishi kerak';
  end if;
  if p_sell_usd is null or p_sell_usd = 'NaN'::numeric or p_sell_usd < 0 or p_sell_usd > 1000000000 then
    raise exception 'Narx notogri';
  end if;

  select qty, avg_cost_usd into v_stock, v_avg from dealer_stock where dealer_id = v_dealer_id and pid = p_pid for update;
  if v_stock is null or v_stock < p_qty then
    raise exception 'Omborda yetarli mahsulot yoq (bor: %, soralgan: %)', coalesce(v_stock,0), p_qty;
  end if;

  select nullif(optim_price, 0), coalesce(point_pct, 0) into v_optim, v_pct
    from catalog_products where id = p_pid and filial = coalesce(v_filial, 'baza');
  v_optim := coalesce(v_optim, nullif(v_avg, 0), p_sell_usd);
  v_pct := coalesce(v_pct, 0);

  -- v24 (31-migratsiya): diller joriy optom narxidan ko'pi bilan 10% chegirma bera oladi
  v_floor := round(v_optim * 0.9, 2);
  if p_sell_usd < v_floor - 0.005 then
    raise exception 'Narx juda past: optom narxidan ko''pi bilan 10%% chegirma mumkin (eng kami % $, optom % $)', v_floor, round(v_optim, 2)
      using errcode = 'P0001';
  end if;

  if v_pct > 0 then
    select data->'settings' into v_settings from app_data where id = 'main';
    v_usd_val := coalesce((v_settings->>'pointUsdValue')::numeric, 2);
    v_step := coalesce(nullif((v_settings->>'pointRoundStep')::numeric, 0), 1);
    if v_usd_val > 0 then
      v_points := round(((p_qty * p_sell_usd * v_pct / 100) / v_usd_val) / v_step) * v_step;
    end if;
  end if;

  update dealer_stock set qty = qty - p_qty, updated_at = now()
    where dealer_id = v_dealer_id and pid = p_pid;

  insert into dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
    values (v_dealer_id, p_pid, left(p_sku, 80), left(p_name, 300), p_qty, p_sell_usd, p_qty*p_sell_usd, current_date);

  update dealers set
    total_sold_usd = total_sold_usd + (p_qty*p_sell_usd),
    debt_usd        = debt_usd + (p_qty*v_optim),
    points          = points + v_points
  where id = v_dealer_id;

  -- Chegirma bilan (optom narxidan past) savdo — auditga va administratorga
  if p_sell_usd < v_optim - 0.005 then
    insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, after, note)
    values (coalesce(v_filial, 'baza'), 'dealer_sale', p_pid::text, 'price_discount', v_dealer_id, left(v_dealer_name, 200), 'dealer',
            jsonb_build_object('pid', p_pid, 'sku', left(p_sku, 80), 'name', left(p_name, 300), 'qty', p_qty, 'sellUsd', p_sell_usd,
                               'optimUsd', round(v_optim, 2), 'discountPct', round((1 - p_sell_usd / nullif(v_optim, 0)) * 100, 2)),
            left('Diller chegirma bilan sotdi: ' || coalesce(p_name, '') || ' — ' || p_qty || ' dona × ' || p_sell_usd || ' $ (optom ' || round(v_optim, 2) || ' $)', 1000));
    insert into public.fw_notifications (filial, audience, kind, title, body, ref_type, ref_id, actor_name, actor_role)
    values (coalesce(v_filial, 'baza'), 'admin', 'dealer_discount', left('Diller chegirma berdi: ' || coalesce(v_dealer_name, ''), 200),
            left(coalesce(p_name, '') || ': ' || p_qty || ' dona × ' || p_sell_usd || ' $ (optom ' || round(v_optim, 2) || ' $). Qarz optom narxda yozildi.', 1000),
            'dealer', v_dealer_id::text, left(v_dealer_name, 200), 'dealer');
  end if;
end;
$function$
;

-- ── 7. DIRECT SALE RUXSATI ─────────────────────────────────────────────
insert into public.permissions (key, module, label) values
  ('savdo.direct_sale', 'savdo', 'Direct Sale: omborda yoʻq mahsulotni taʼminotchi hisobidan sotish')
on conflict (key) do nothing;
insert into public.role_permissions (role_id, permission_id)
select distinct rp.role_id, pd.id
  from public.role_permissions rp
  join public.permissions pc on pc.id = rp.permission_id and pc.key = 'savdo.create'
  join public.roles r on r.id = rp.role_id and r.key not in ('employee', 'dealer')
  cross join public.permissions pd
 where pd.key = 'savdo.direct_sale'
on conflict (role_id, permission_id) do nothing;

-- ── 8. Funksiya huquqlari (faqat server) ───────────────────────────────
revoke all on function public._fw_audit_immutable() from public, anon, authenticated;
revoke all on function public._fw_notif_guard() from public, anon, authenticated;
revoke all on function public.fw_edit_window_days(text) from public, anon, authenticated;
revoke all on function public.fw_sale_created_at(public.sales) from public, anon, authenticated;
revoke all on function public._fw_assert_sale_edit(public.sales, text, bigint, boolean) from public, anon, authenticated;
revoke all on function public._fw_sale_snapshot(bigint) from public, anon, authenticated;
revoke all on function public.sale_edit_guarded(text, text, text, text, jsonb, bigint, text, text, boolean) from public, anon, authenticated;
revoke all on function public.sale_void_guarded(text, text, text, jsonb, jsonb, bigint, text, text, boolean) from public, anon, authenticated;
revoke all on function public.sale_checkout_guarded(text, text, jsonb, jsonb, bigint, text, text, boolean) from public, anon, authenticated;
grant execute on function public.fw_edit_window_days(text) to service_role;
grant execute on function public.fw_sale_created_at(public.sales) to service_role;
grant execute on function public.sale_edit_guarded(text, text, text, text, jsonb, bigint, text, text, boolean) to service_role;
grant execute on function public.sale_void_guarded(text, text, text, jsonb, jsonb, bigint, text, text, boolean) to service_role;
grant execute on function public.sale_checkout_guarded(text, text, jsonb, jsonb, bigint, text, text, boolean) to service_role;
-- record_dealer_sale (7 argumentli) — `create or replace` mavjud huquqlarni saqlaydi (23-migratsiyadagi kabi dillerga ochiq);
-- bu migratsiya brauzer rollariga hech qanday yangi huquq bermaydi.

comment on table public.fw_audit_events is '31-migratsiya: savdo yaratish/tahrir/o''chirish, zararli savdo, diller chegirmasi va reviziya — o''zgarmas audit tarixi';
comment on table public.fw_notifications is '31-migratsiya: bildirishnomalar (7 kundan keyin arxiv; o''chirilmaydi). Faqat read_at o''zgaradi';

-- ────────────────────────────────────────────────────────────────────
-- 16. 32-migratsiya: DILLER REVIZIYASI — ADMIN TASDIG'I BILAN SOTUV/QAYTISH, ZARAR SUMMASI, XODIM ROLIGA DIRECT SALE
-- (supabase-migration-32-reviziya-tasdiq-direct-sale.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 32-MIGRATSIYA (v24.2): DILLER REVIZIYASI — ADMIN TASDIG'I BILAN SOTUV/QAYTISH,
--                        ZARAR SUMMASI SOTUVCHIGA, «XODIM» ROLIGA DIRECT SALE
-- Egasi tasdiqlagan qoidalar (2026-10-13):
--   • Diller reviziyasi: diller sanaydi va yuboradi → administrator (yoki «dillerlar.manage») TASDIQLASA:
--       kamomad  → SOTUV  (diller omboridan chiqadi, qarz optom narxda oshadi — oddiy diller savdosi kabi);
--       ortiqcha → QAYTISH (avval sotilgan deb yozilgan tovar omborga qaytadi, qarz optom narxda kamayadi;
--                  qarzdan oshsa — dillerning haqi (manfiy qarz) bo'ladi). Hech qachon sotilmagan miqdordan ortig'i —
--                  «noma'lum ortiqcha»: faqat ombor qoldig'iga qo'shiladi, pulga ta'sir qilmaydi.
--     Rad etilsa — hech narsa o'zgarmaydi. Har qaror — o'zgarmas auditda, dillerga bildirishnoma.
--     Reviziyadan keyin qoldiq o'zgargan bo'lsa (yangi savdo/jo'natma) — tasdiq rad etiladi (qayta reviziya kerak).
--   • Tannarxdan past savdo: sotuvchiga ZARAR SUMMASI ko'rsatiladi (server javobida ham).
--   • «savdo.direct_sale» — oddiy «Xodim» (employee) roliga ham beriladi; diller — yo'q.
-- Faqat qo'shadi; mavjud yozuvlar o'chirilmaydi/o'zgartirilmaydi; qayta ishga tushirish xavfsiz.
-- Talab: 31-migratsiya.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.fw_audit_events') is null or to_regclass('public.fw_notifications') is null
     or not exists (select 1 from pg_proc where proname = 'sale_checkout_guarded') then
    raise exception '32-migratsiya: avval 31-migratsiyani qo''llang';
  end if;
end $$;

-- ── 1. Audit va bildirishnoma turlari kengaytiriladi ───────────────────
alter table public.fw_audit_events drop constraint if exists fw_audit_events_action_chk;
alter table public.fw_audit_events add constraint fw_audit_events_action_chk
  check (action in ('create','edit','void','loss_sale','price_discount','revision','announce','revision_apply','revision_reject'));
alter table public.fw_notifications drop constraint if exists fw_notifications_kind_chk;
alter table public.fw_notifications add constraint fw_notifications_kind_chk
  check (kind in ('sale_edit','sale_void','loss_sale','dealer_discount','dealer_revision','dealer_pay','announce_error','system','dealer_revision_result'));

-- ── 2. Diller savdolarida manba (reviziyadan kelgan yozuvlar ajralib turadi) ──
alter table public.dealer_sales add column if not exists source text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'dealer_sales_source_chk' and conrelid = 'public.dealer_sales'::regclass) then
    alter table public.dealer_sales add constraint dealer_sales_source_chk check (source is null or source in ('revision_short','revision_surplus'));
  end if;
end $$;
comment on column public.dealer_sales.source is '32-migratsiya: null — oddiy savdo; revision_short — reviziya kamomadi (sotuv); revision_surplus — reviziya ortiqchasi (qaytish, qty manfiy)';

-- ── 3. REVIZIYALAR (kutilmoqda → tasdiqlandi / rad etildi) ─────────────
create table if not exists public.fw_dealer_revisions (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null default 'baza',
  dealer_id bigint not null references public.dealers(id),
  dealer_name text,
  lines jsonb not null,
  reason text,
  shortage_qty numeric not null default 0,
  surplus_qty numeric not null default 0,
  status text not null default 'pending',
  op_key text not null,
  decided_at timestamp with time zone,
  decided_by_id bigint,
  decided_by_name text,
  decided_role text,
  decision_note text,
  result jsonb,
  constraint fw_dealer_revisions_status_chk check (status in ('pending','approved','rejected')),
  constraint fw_dealer_revisions_lines_chk check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 500),
  constraint fw_dealer_revisions_len_chk check (coalesce(length(reason),0) <= 500 and coalesce(length(decision_note),0) <= 500
    and coalesce(length(dealer_name),0) <= 200 and coalesce(length(decided_by_name),0) <= 200 and length(op_key) <= 160 and length(filial) <= 40),
  constraint fw_dealer_revisions_decided_chk check ((status = 'pending') = (decided_at is null))
);
create unique index if not exists fw_dealer_revisions_op_uq on public.fw_dealer_revisions (op_key);
create index if not exists idx_fw_dealer_revisions_st on public.fw_dealer_revisions (filial, status, created_at desc);
create index if not exists idx_fw_dealer_revisions_dealer on public.fw_dealer_revisions (dealer_id, created_at desc);

-- Faqat bir marta qaror: kutilmoqda → tasdiqlandi/rad etildi; mazmun o'zgarmaydi, o'chirilmaydi
create or replace function public._fw_rev_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if tg_op <> 'UPDATE' then
    raise exception 'REVIZIYA: yozuvni o''chirib bo''lmaydi' using errcode = 'P0001';
  end if;
  if old.status <> 'pending' then
    raise exception 'REVIZIYA: qaror allaqachon qabul qilingan' using errcode = 'P0001';
  end if;
  if (to_jsonb(new) - array['status','decided_at','decided_by_id','decided_by_name','decided_role','decision_note','result'])
     <> (to_jsonb(old) - array['status','decided_at','decided_by_id','decided_by_name','decided_role','decision_note','result']) then
    raise exception 'REVIZIYA: sanoq natijasini o''zgartirib bo''lmaydi' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create or replace trigger fw_dealer_revisions_guard before update or delete on public.fw_dealer_revisions
  for each row execute function public._fw_rev_guard();
create or replace trigger fw_dealer_revisions_no_truncate before truncate on public.fw_dealer_revisions
  for each statement execute function public._fw_rev_guard();

alter table public.fw_dealer_revisions enable row level security;
revoke all on public.fw_dealer_revisions from anon, authenticated;
grant select, insert on public.fw_dealer_revisions to service_role;
grant update (status, decided_at, decided_by_id, decided_by_name, decided_role, decision_note, result) on public.fw_dealer_revisions to service_role;
grant usage on sequence public.fw_dealer_revisions_id_seq to service_role;

-- ── 4. QAROR — bitta tranzaksiyada (ombor, qarz, savdo yozuvi, audit, bildirishnoma) ──
create or replace function public.dealer_revision_decide(
  p_id bigint, p_approve boolean, p_actor_id bigint, p_actor_name text, p_actor_role text, p_note text, p_filial text)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_rev public.fw_dealer_revisions%rowtype;
  v_line jsonb;
  v_pid bigint;
  v_diff numeric;
  v_sys numeric;
  v_cur numeric;
  v_avg numeric;
  v_optim numeric;
  v_sold numeric;
  v_ret numeric;
  v_sku text;
  v_name text;
  v_debt numeric := 0;
  v_effects jsonb := '[]'::jsonb;
  v_result jsonb;
  v_note text := left(nullif(btrim(coalesce(p_note, '')), ''), 500);
begin
  if p_actor_role not in ('admin','seller') then
    raise exception 'REVIZIYA: rol noto''g''ri' using errcode = 'P0001';
  end if;
  select * into v_rev from public.fw_dealer_revisions where id = p_id for update;
  if not found then
    raise exception 'REVIZIYA: topilmadi' using errcode = 'P0001';
  end if;
  -- Filial chegarasi: p_filial null — barcha filial (administrator); aks holda faqat o'z filiali
  if p_filial is not null and v_rev.filial <> p_filial then
    raise exception 'REVIZIYA: boshqa filial' using errcode = 'P0001';
  end if;
  if v_rev.status <> 'pending' then
    -- takror bosish: avvalgi natija qaytariladi, hech narsa qayta yozilmaydi
    return jsonb_build_object('id', v_rev.id, 'status', v_rev.status, 'replay', true, 'result', v_rev.result);
  end if;

  if not coalesce(p_approve, false) then
    update public.fw_dealer_revisions set status = 'rejected', decided_at = now(), decided_by_id = p_actor_id,
      decided_by_name = left(p_actor_name, 200), decided_role = p_actor_role, decision_note = v_note,
      result = jsonb_build_object('applied', false)
     where id = p_id;
    insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
    values (v_rev.filial, 'dealer_stock', v_rev.dealer_id::text, 'revision_reject', p_actor_id, left(p_actor_name, 200), p_actor_role,
            jsonb_build_object('revisionId', v_rev.id, 'lines', v_rev.lines), null,
            left('Reviziya rad etildi: ' || coalesce(v_rev.dealer_name, '') || coalesce(' — ' || v_note, ''), 1000), 'drevd:' || v_rev.id)
    on conflict do nothing;
    insert into public.fw_notifications (filial, audience, audience_id, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
    values (v_rev.filial, 'dealer', v_rev.dealer_id, 'dealer_revision_result', 'Reviziya rad etildi',
            left('Administrator reviziyangizni rad etdi. Qoldiq va qarz oʻzgarmadi.' || coalesce(' Izoh: ' || v_note, ''), 1000),
            'dealer_revision', v_rev.id::text, left(p_actor_name, 200), p_actor_role, 'drevd:' || v_rev.id)
    on conflict do nothing;
    return jsonb_build_object('id', v_rev.id, 'status', 'rejected', 'replay', false);
  end if;

  -- Diller qatorini qulflash (qarz bir vaqtda boshqa amal bilan o'zgarmasin)
  perform 1 from public.dealers where id = v_rev.dealer_id for update;

  for v_line in select * from jsonb_array_elements(v_rev.lines) loop
    v_pid := (v_line->>'pid')::bigint;
    v_diff := coalesce((v_line->>'diff')::numeric, 0);
    v_sys := coalesce((v_line->>'system')::numeric, 0);
    if v_diff = 0 then continue; end if;
    select qty, avg_cost_usd, sku, name into v_cur, v_avg, v_sku, v_name
      from public.dealer_stock where dealer_id = v_rev.dealer_id and pid = v_pid for update;
    v_cur := coalesce(v_cur, 0);
    if abs(v_cur - v_sys) > 0.0005 then
      raise exception 'REV_STALE: % — reviziyadan keyin qoldiq oʻzgargan (reviziyada %, hozir %). Dillerdan qayta reviziya soʻrang',
        coalesce(v_line->>'name', v_pid::text), v_sys, v_cur using errcode = 'P0001';
    end if;
    select nullif(optim_price, 0) into v_optim from public.catalog_products where id = v_pid and filial = v_rev.filial;
    v_optim := round(coalesce(v_optim, nullif(v_avg, 0), 0), 2);
    v_sku := coalesce(v_sku, left(v_line->>'sku', 80));
    v_name := coalesce(v_name, left(v_line->>'name', 300));

    if v_diff < 0 then
      -- KAMOMAD → SOTUV (optom narxda; record_dealer_sale bilan bir xil qarz qoidasi)
      update public.dealer_stock set qty = qty + v_diff, updated_at = now() where dealer_id = v_rev.dealer_id and pid = v_pid;
      insert into public.dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date, source)
      values (v_rev.dealer_id, v_pid, v_sku, v_name, -v_diff, v_optim, round(-v_diff * v_optim, 2), current_date, 'revision_short');
      v_debt := v_debt + round(-v_diff * v_optim, 2);
      v_effects := v_effects || jsonb_build_array(jsonb_build_object('pid', v_pid, 'name', v_name, 'kind', 'sale', 'qty', -v_diff,
                     'priceUsd', v_optim, 'amountUsd', round(-v_diff * v_optim, 2)));
    else
      -- ORTIQCHA → QAYTISH: faqat avval sotilgan (sof) miqdorgacha; ortig'i — «noma'lum ortiqcha» (faqat qoldiq)
      select coalesce(sum(qty), 0) into v_sold from public.dealer_sales where dealer_id = v_rev.dealer_id and pid = v_pid;
      v_ret := greatest(0, least(v_diff, v_sold));
      insert into public.dealer_stock (dealer_id, pid, sku, name, qty, avg_cost_usd)
      values (v_rev.dealer_id, v_pid, v_sku, v_name, v_diff, coalesce(v_avg, 0))
      on conflict (dealer_id, pid) do update set qty = public.dealer_stock.qty + excluded.qty, updated_at = now();
      if v_ret > 0 then
        insert into public.dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date, source)
        values (v_rev.dealer_id, v_pid, v_sku, v_name, -v_ret, v_optim, -round(v_ret * v_optim, 2), current_date, 'revision_surplus');
        v_debt := v_debt - round(v_ret * v_optim, 2);
      end if;
      v_effects := v_effects || jsonb_build_array(jsonb_build_object('pid', v_pid, 'name', v_name, 'kind', 'return', 'qty', v_ret,
                     'unknownQty', v_diff - v_ret, 'priceUsd', v_optim, 'amountUsd', -round(v_ret * v_optim, 2)));
    end if;
  end loop;

  update public.dealers set debt_usd = debt_usd + v_debt, total_sold_usd = total_sold_usd + v_debt where id = v_rev.dealer_id;

  v_result := jsonb_build_object('applied', true, 'debtDeltaUsd', v_debt, 'effects', v_effects);
  update public.fw_dealer_revisions set status = 'approved', decided_at = now(), decided_by_id = p_actor_id,
    decided_by_name = left(p_actor_name, 200), decided_role = p_actor_role, decision_note = v_note, result = v_result
   where id = p_id;
  insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
  values (v_rev.filial, 'dealer_stock', v_rev.dealer_id::text, 'revision_apply', p_actor_id, left(p_actor_name, 200), p_actor_role,
          jsonb_build_object('revisionId', v_rev.id, 'lines', v_rev.lines), v_result,
          left('Reviziya tasdiqlandi: ' || coalesce(v_rev.dealer_name, '') || ' — qarz ' || case when v_debt >= 0 then '+' else '' end || v_debt || ' $', 1000),
          'drevd:' || v_rev.id)
  on conflict do nothing;
  insert into public.fw_notifications (filial, audience, audience_id, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
  values (v_rev.filial, 'dealer', v_rev.dealer_id, 'dealer_revision_result', 'Reviziya tasdiqlandi',
          left('Kamomad sotuv, ortiqcha qaytish sifatida yozildi. Qarzingiz ' || case when v_debt >= 0 then '+' else '−' end
               || abs(v_debt) || ' $ oʻzgardi.' || coalesce(' Izoh: ' || v_note, ''), 1000),
          'dealer_revision', v_rev.id::text, left(p_actor_name, 200), p_actor_role, 'drevd:' || v_rev.id)
  on conflict do nothing;
  return jsonb_build_object('id', v_rev.id, 'status', 'approved', 'replay', false, 'result', v_result);
end;
$$;

-- ── 5. SAVDO — zarar summasi xabarda (sotuvchiga ko'rsatiladi; egasi qarori 2026-10-13) ──
-- 31-migratsiyadagi tana o'zgarmagan; faqat LOSS_ACK_REQUIRED xabariga «|loss=<$>» qo'shildi.
create or replace function public.sale_checkout_guarded(
  p_filial text, p_op_key text, p_sale jsonb, p_box_payments jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_loss_ack boolean default false)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_res jsonb;
  v_total numeric;
  v_cost numeric;
  v_loss numeric;
  v_items jsonb;
begin
  if p_role not in ('admin','seller') then
    raise exception 'SAVDO: rol noto''g''ri' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.ledger_ops where filial = p_filial and op_key = p_op_key) then
    return public.sale_checkout_atomic_v3(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name);
  end if;
  v_res := public.sale_checkout_atomic_v3(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name);
  v_total := coalesce((v_res->>'totalUsd')::numeric, 0);
  v_cost := coalesce((v_res->>'costUsd')::numeric, 0);
  v_loss := round(v_cost - v_total, 2);
  if v_loss > 0.005 and p_role <> 'admin' and not coalesce(p_loss_ack, false) then
    -- Tranzaksiya to'liq bekor bo'ladi (ombor, kassa, qarz, savdo hujjati — hech biri yozilmaydi)
    raise exception 'LOSS_ACK_REQUIRED: savdo tannarxdan past (zarar) — sotuvchi tasdig''i kerak |loss=%', v_loss using errcode = 'P0001';
  end if;
  v_items := coalesce(v_res->'sale'->'items', '[]'::jsonb);
  insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
  values (p_filial, 'sale', v_res->>'localId', 'create', p_staff_id, left(p_staff_name, 200), p_role, null, v_res->'sale',
          left('Savdo: ' || coalesce(v_res->>'inv', ''), 1000), p_op_key)
  on conflict do nothing;
  if v_loss > 0.005 then
    insert into public.fw_audit_events (filial, entity, entity_id, action, actor_id, actor_name, actor_role, before, after, note, op_key)
    values (p_filial, 'sale', v_res->>'localId', 'loss_sale', p_staff_id, left(p_staff_name, 200), p_role, null,
            jsonb_build_object('inv', v_res->>'inv', 'totalUsd', v_total, 'costUsd', v_cost, 'lossUsd', v_loss, 'items', v_items,
                               'confirmedBy', p_staff_name, 'confirmedRole', p_role, 'confirmedAt', now()),
            left('Zarar bilan savdo tasdiqlandi: ' || coalesce(v_res->>'inv', '') || ' — zarar ' || v_loss || ' $', 1000), p_op_key)
    on conflict do nothing;
    if p_role <> 'admin' then
      insert into public.fw_notifications (filial, audience, kind, title, body, ref_type, ref_id, actor_name, actor_role, dedupe_key)
      values (p_filial, 'admin', 'loss_sale', left('Zarar bilan savdo: ' || coalesce(v_res->>'inv', ''), 200),
              left(coalesce(p_staff_name, 'Xodim') || ' tannarxdan past sotdi va tasdiqladi. Savdo ' || round(v_total, 2) || ' $, tannarx '
                   || round(v_cost, 2) || ' $, zarar ' || v_loss || ' $.', 1000),
              'sale', v_res->>'localId', left(p_staff_name, 200), p_role, 'loss_sale:' || p_filial || ':' || p_op_key)
      on conflict do nothing;
    end if;
  end if;
  return v_res;
end;
$$;

-- ── 6. «Xodim» (employee) roliga Direct Sale (diller — yo'q) ───────────
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r cross join public.permissions p
 where r.key = 'employee' and p.key = 'savdo.direct_sale'
on conflict (role_id, permission_id) do nothing;

-- ── 7. Funksiya huquqlari (faqat server) ───────────────────────────────
revoke all on function public._fw_rev_guard() from public, anon, authenticated;
revoke all on function public.dealer_revision_decide(bigint, boolean, bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function public.dealer_revision_decide(bigint, boolean, bigint, text, text, text, text) to service_role;
revoke all on function public.sale_checkout_guarded(text, text, jsonb, jsonb, bigint, text, text, boolean) from public, anon, authenticated;
grant execute on function public.sale_checkout_guarded(text, text, jsonb, jsonb, bigint, text, text, boolean) to service_role;

comment on table public.fw_dealer_revisions is '32-migratsiya: diller reviziyalari — kutilmoqda / tasdiqlandi (kamomad → sotuv, ortiqcha → qaytish) / rad etildi. O''chirilmaydi';

-- ────────────────────────────────────────────────────────────────────
-- 17. 33-migratsiya: TA'MINOTCHIGA ZAKLAD (yuanda, $ kassadan; xizmat — xarajat; zakladdan qarzni yopish)
-- (supabase-migration-33-taminotchi-zaklad.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 33-MIGRATSIYA (v24.4): TA'MINOTCHIGA ZAKLAD (OLDINDAN TO'LOV) — YUANDA, $ KASSADAN
-- Egasi tasdiqlagan qoida (2026-10-14):
--   • Xitoy ta'minotchisiga zaklad yuanda beriladi: masalan 10 000 ¥ + 0,6% xizmat, kurs 6,65 →
--     kassadan 1 512,78 $ chiqadi; ta'minotchiga faqat 10 000 ¥ (= 1 503,76 $) zaklad bo'lib yoziladi,
--     0,6% (9,02 $) — alohida XARAJAT («Pul o'tkazish xizmati»).
--   • Pul har doim $ kassadan chiqadi (filial $ kassasi yoki Bosh kassa $). Filiallarda ham.
--   • Zaklad ta'minotchining QARZIDAN ALOHIDA hisob: mavjud qarz qoidalari (qarz manfiy bo'lmaydi) o'zgarmaydi.
--     Tovar kelgach (kirim — qarz) administrator «Zakladdan yopish» bilan qarzni zakladdan kamaytiradi
--     (qarzdan ham, zakladdan ham ortiq emas) — bitta tranzaksiyada, to'lov tarixiga yoziladi.
-- Hammasi bitta tranzaksiyada (kassa, zaklad, xarajat, jurnal); takror so'rov ikki marta yozilmaydi.
-- Faqat qo'shadi; mavjud ma'lumot o'chirilmaydi/o'zgartirilmaydi; qayta ishga tushirish xavfsiz.
-- Talab: 24 (kassa), 27 (qarz jurnali, ledger_ops), 28 (Bosh kassa — ta'minotchi to'lovi va xarajat).
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.ledger_ops') is null or not exists (select 1 from pg_proc where proname = '_supp_debt_move')
     or not exists (select 1 from pg_proc where proname = 'cashbox_apply_ops') or not exists (select 1 from pg_proc where proname = 'firma_supplier_pay') then
    raise exception '33-migratsiya: avval 24, 27 va 28-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Zaklad qoldig'i (ta'minotchi bo'yicha, $) va o'zgarmas jurnal ──
create table if not exists public.supplier_advance_balances (
  filial text not null,
  supplier_local_id bigint not null,
  balance_usd numeric(20,4) not null default 0,
  updated_at timestamp with time zone not null default now(),
  primary key (filial, supplier_local_id),
  constraint supplier_advance_balances_nonneg check (balance_usd >= 0)
);
create table if not exists public.supplier_advance_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  supplier_local_id bigint not null,
  supplier_name text,
  kind text not null,
  cny_amount numeric(20,2),
  fee_pct numeric(6,3),
  rate numeric(14,6),
  usd_amount numeric(20,4) not null,
  fee_usd numeric(20,4) not null default 0,
  source text,
  box_local_id integer,
  fk_entry_id bigint,
  balance_after numeric(20,4) not null,
  op_key text not null,
  note text,
  staff_id bigint,
  staff_name text,
  constraint supplier_advance_ledger_kind_chk check (kind in ('advance','apply')),
  constraint supplier_advance_ledger_amt_chk check (usd_amount > 0 and fee_usd >= 0 and balance_after >= 0),
  constraint supplier_advance_ledger_src_chk check (source is null or source in ('box','firma')),
  constraint supplier_advance_ledger_len_chk check (length(op_key) <= 160 and coalesce(length(note),0) <= 500
    and coalesce(length(supplier_name),0) <= 200 and coalesce(length(staff_name),0) <= 200 and length(filial) <= 40),
  constraint supplier_advance_ledger_op_uq unique (filial, op_key, kind)
);
create index if not exists idx_supp_adv_ledger_party on public.supplier_advance_ledger (filial, supplier_local_id, id desc);

-- Qoldiq faqat zaklad funksiyalari orqali o'zgaradi; jurnal o'zgarmas
create or replace function public._fw_adv_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if tg_table_name = 'supplier_advance_balances' and coalesce(current_setting('fw.adv_move', true), '') = '1' and tg_op <> 'DELETE' then
    return new;
  end if;
  raise exception 'ZAKLAD: zaklad faqat zaklad amallari orqali o''zgaradi (jurnal o''zgarmas)' using errcode = 'P0001';
end;
$$;
create or replace trigger supplier_advance_balances_guard before insert or update or delete on public.supplier_advance_balances
  for each row execute function public._fw_adv_guard();
create or replace trigger supplier_advance_ledger_immutable before update or delete on public.supplier_advance_ledger
  for each row execute function public._fw_adv_guard();
create or replace trigger supplier_advance_ledger_no_truncate before truncate on public.supplier_advance_ledger
  for each statement execute function public._fw_adv_guard();

alter table public.supplier_advance_balances enable row level security;
alter table public.supplier_advance_ledger enable row level security;
revoke all on public.supplier_advance_balances, public.supplier_advance_ledger from anon, authenticated;
grant select, insert, update on public.supplier_advance_balances to service_role;
grant select, insert on public.supplier_advance_ledger to service_role;
grant usage on sequence public.supplier_advance_ledger_id_seq to service_role;

-- ── 2. Amal turlari kengaytiriladi ─────────────────────────────────────
alter table public.cashbox_ledger drop constraint if exists cashbox_ledger_kind_chk;
alter table public.cashbox_ledger add constraint cashbox_ledger_kind_chk check (op_kind in (
  'opening','sale','sale_fix','manual_in','manual_out','move','exchange','expense','expense_fix','salary',
  'cust_debt_pay','supp_pay','kirim_pay','dealer_pay','home_withdrawal','branch_to_firma','firma_to_branch','reset_zero',
  'branch_loan_in','branch_loan_repay','supp_advance'));
alter table public.ledger_ops drop constraint if exists ledger_ops_kind_chk;
alter table public.ledger_ops add constraint ledger_ops_kind_chk check (kind in ('sale','sale_return','sale_void','sale_edit','cust_set','supp_set',
  'batches_create','batch_edit','batch_delete','batch_arrive','revision','stock_out','firma_supp_pay',
  'writeoff','writeoff_cancel','b2b_ship','b2b_receive','b2b_ack','b2b_restock','supp_advance','supp_advance_apply'));

-- ── 3. ZAKLAD BERISH: ¥ + xizmat % → $ kassadan; ta'minotchiga ¥ (=$), xizmat — xarajat ──
create or replace function public.supplier_advance_pay(
  p_filial text, p_op_key text, p_supp bigint, p_supp_name text, p_source text, p_box integer, p_box_name text,
  p_cny numeric, p_fee_pct numeric, p_rate numeric, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  v_cny numeric;
  v_usd numeric;
  v_fee numeric;
  v_bal numeric;
  v_cb jsonb := null;
  v_fk public.firma_kassa_ledger;
  v_fk_id bigint := null;
  v_fk_bal numeric := null;
  v_ops jsonb;
  v_note text;
  v_res jsonb;
begin
  if coalesce(p_filial, '') = '' or p_supp is null or p_supp <= 0 then
    raise exception 'ZAKLAD: ta''minotchi noto''g''ri' using errcode = 'P0001';
  end if;
  if p_source is null or p_source not in ('box','firma') or (p_source = 'box' and (p_box is null or p_box < 0)) then
    raise exception 'ZAKLAD: pul manbai noto''g''ri' using errcode = 'P0001';
  end if;
  if p_cny is null or p_cny = 'NaN'::numeric or p_cny <= 0 or p_cny > 1000000000 then
    raise exception 'ZAKLAD: yuan summasi musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  if p_fee_pct is null or p_fee_pct = 'NaN'::numeric or p_fee_pct < 0 or p_fee_pct > 5 then
    raise exception 'ZAKLAD: xizmat foizi 0–5%% oralig''ida bo''lishi kerak' using errcode = 'P0001';
  end if;
  if p_rate is null or p_rate = 'NaN'::numeric or p_rate < 1 or p_rate > 50 then
    raise exception 'ZAKLAD: yuan kursi noto''g''ri (1 $ = ? ¥)' using errcode = 'P0001';
  end if;
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'supp_advance');
  if v_prev is not null then return v_prev; end if;

  v_cny := round(p_cny, 2);
  v_usd := round(v_cny / p_rate, 2);
  v_fee := round(v_cny * p_fee_pct / 100 / p_rate, 2);
  if v_usd <= 0 then raise exception 'ZAKLAD: summa juda kichik' using errcode = 'P0001'; end if;
  v_note := left(coalesce(nullif(btrim(p_note), ''), 'Zaklad') || ' — ' || v_cny || ' ¥, kurs ' || round(p_rate, 4)
                 || case when v_fee > 0 then ', xizmat ' || round(p_fee_pct, 3) || '%' else '' end, 500);

  if p_source = 'box' then
    v_ops := jsonb_build_array(jsonb_build_object('box', p_box, 'currency', 'USD', 'dir', 'out', 'amount', v_usd, 'box_name', left(p_box_name, 200),
                                                  'ref_type', 'supplier_advance', 'ref_id', p_supp::text, 'note', left('Zaklad: ' || coalesce(p_supp_name, '') || ' — ' || v_note, 500)));
    if v_fee > 0 then
      v_ops := v_ops || jsonb_build_array(jsonb_build_object('box', p_box, 'currency', 'USD', 'dir', 'out', 'amount', v_fee, 'box_name', left(p_box_name, 200),
                                                             'ref_type', 'expense', 'ref_id', 'transfer_fee', 'note', left('Pul oʻtkazish xizmati (zaklad: ' || coalesce(p_supp_name, '') || ')', 500)));
    end if;
    v_cb := public.cashbox_apply_ops(p_filial, 'sadv:' || p_op_key, 'supp_advance', v_ops, p_staff_id, p_staff_name);
  else
    v_fk := public._fk_cash_move('USD', 'out', v_usd, 'supplier_payment', 'supplier', p_supp::text, left(p_supp_name, 200),
                                 p_filial, 'supplier_advance', p_supp::text, v_note, p_staff_id, p_staff_name, 'sadv:' || p_filial || ':' || p_op_key);
    v_fk_id := v_fk.id; v_fk_bal := v_fk.balance_after;
    if v_fee > 0 then
      v_fk := public._fk_cash_move('USD', 'out', v_fee, 'expense', null, null, 'Pul oʻtkazish xizmati',
                                   p_filial, 'expense', 'transfer_fee', left('Zaklad xizmati: ' || coalesce(p_supp_name, ''), 500), p_staff_id, p_staff_name,
                                   'sadvf:' || p_filial || ':' || p_op_key);
      v_fk_bal := v_fk.balance_after;
    end if;
  end if;

  perform set_config('fw.adv_move', '1', true);
  insert into public.supplier_advance_balances (filial, supplier_local_id, balance_usd) values (p_filial, p_supp, v_usd)
    on conflict (filial, supplier_local_id) do update set balance_usd = public.supplier_advance_balances.balance_usd + excluded.balance_usd, updated_at = now()
    returning balance_usd into v_bal;
  perform set_config('fw.adv_move', '', true);
  insert into public.supplier_advance_ledger (filial, supplier_local_id, supplier_name, kind, cny_amount, fee_pct, rate, usd_amount, fee_usd, source,
                                              box_local_id, fk_entry_id, balance_after, op_key, note, staff_id, staff_name)
  values (p_filial, p_supp, left(p_supp_name, 200), 'advance', v_cny, round(p_fee_pct, 3), round(p_rate, 6), v_usd, v_fee, p_source,
          case when p_source = 'box' then p_box end, v_fk_id, v_bal, p_op_key, left(p_note, 500), p_staff_id, left(p_staff_name, 200));

  v_res := jsonb_build_object('ok', true, 'cny', v_cny, 'feePct', round(p_fee_pct, 3), 'rate', round(p_rate, 6), 'usd', v_usd, 'feeUsd', v_fee,
    'totalUsd', v_usd + v_fee, 'advanceUsd', v_bal, 'source', p_source,
    'balances', coalesce(v_cb->'balances', '{}'::jsonb), 'firmaBalance', v_fk_bal, 'fkEntryId', v_fk_id);
  return public._ledger_op_finish(p_filial, p_op_key, 'supp_advance', v_res, null, array[p_supp], null, p_staff_id, p_staff_name);
end;
$$;

-- ── 4. ZAKLADDAN YOPISH: ta'minotchi qarzi zakladdan kamayadi (qarzdan ham, zakladdan ham ortiq emas) ──
create or replace function public.supplier_advance_apply(
  p_filial text, p_op_key text, p_supp bigint, p_supp_name text, p_amount_usd numeric,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_prev jsonb;
  v_amt numeric;
  v_bal numeric;
  v_debt numeric;
  v_res jsonb;
begin
  if coalesce(p_filial, '') = '' or p_supp is null or p_supp <= 0 then
    raise exception 'ZAKLAD: ta''minotchi noto''g''ri' using errcode = 'P0001';
  end if;
  if p_amount_usd is null or p_amount_usd = 'NaN'::numeric or p_amount_usd <= 0 or p_amount_usd > 1000000000 then
    raise exception 'ZAKLAD: summa musbat bo''lishi kerak' using errcode = 'P0001';
  end if;
  v_prev := public._ledger_op_replay(p_filial, p_op_key, 'supp_advance_apply');
  if v_prev is not null then return v_prev; end if;

  v_amt := round(p_amount_usd, 2);
  select balance_usd into v_bal from public.supplier_advance_balances where filial = p_filial and supplier_local_id = p_supp for update;
  v_bal := coalesce(v_bal, 0);
  if v_amt > v_bal + 0.005 then
    raise exception 'ZAKLAD: summa (% $) zakladdan (% $) ko''p', v_amt, round(v_bal, 2) using errcode = 'P0001';
  end if;
  v_amt := least(v_amt, v_bal);
  -- qarzdan ortiq bo'lsa _supp_debt_move rad etadi (strict)
  v_debt := public._supp_debt_move(p_filial, p_supp, -v_amt, v_amt, 'strict', 'payment', 'sadp:' || p_op_key, p_op_key,
                                   'supplier_advance', null, left('Zakladdan: ' || coalesce(p_supp_name, ''), 500), p_staff_id, p_staff_name);
  perform set_config('fw.adv_move', '1', true);
  update public.supplier_advance_balances set balance_usd = round(balance_usd - v_amt, 4), updated_at = now()
   where filial = p_filial and supplier_local_id = p_supp returning balance_usd into v_bal;
  perform set_config('fw.adv_move', '', true);
  insert into public.supplier_advance_ledger (filial, supplier_local_id, supplier_name, kind, usd_amount, balance_after, op_key, note, staff_id, staff_name)
  values (p_filial, p_supp, left(p_supp_name, 200), 'apply', v_amt, v_bal, p_op_key, 'Qarz zakladdan yopildi', p_staff_id, left(p_staff_name, 200));
  insert into public.supplier_payments (filial, supplier_local_id, supplier_name, amount_usd, box_local_id, staff_id, staff_name, idem_key)
  values (p_filial, p_supp, left(p_supp_name, 200), v_amt, null, p_staff_id, left(p_staff_name, 200), 'sadp:' || p_op_key);

  v_res := jsonb_build_object('ok', true, 'appliedUsd', v_amt, 'advanceUsd', v_bal,
    'supplierDebt', (select debt from public.supplier_balances where filial = p_filial and supplier_local_id = p_supp),
    'supplierPaid', (select total_paid from public.supplier_balances where filial = p_filial and supplier_local_id = p_supp));
  return public._ledger_op_finish(p_filial, p_op_key, 'supp_advance_apply', v_res, null, array[p_supp], null, p_staff_id, p_staff_name);
end;
$$;

-- ── 5. Funksiya huquqlari (faqat server) ───────────────────────────────
revoke all on function public._fw_adv_guard() from public, anon, authenticated;
revoke all on function public.supplier_advance_pay(text, text, bigint, text, text, integer, text, numeric, numeric, numeric, text, bigint, text) from public, anon, authenticated;
revoke all on function public.supplier_advance_apply(text, text, bigint, text, numeric, bigint, text) from public, anon, authenticated;
grant execute on function public.supplier_advance_pay(text, text, bigint, text, text, integer, text, numeric, numeric, numeric, text, bigint, text) to service_role;
grant execute on function public.supplier_advance_apply(text, text, bigint, text, numeric, bigint, text) to service_role;

comment on table public.supplier_advance_balances is '33-migratsiya: ta''minotchiga berilgan zaklad (oldindan to''lov) qoldig''i, $ — qarzdan alohida';
comment on table public.supplier_advance_ledger is '33-migratsiya: zaklad jurnali (berish ¥ → $, xizmat — xarajat; qarzni zakladdan yopish). O''zgarmas';

-- ────────────────────────────────────────────────────────────────────
-- 18. 34-migratsiya: MIJOZ HAQI (ortiqcha toʻlov — avval qarzdan, qolgani haqqa; savdoda haqdan foydalanish; toʻlov kassaga tushumdan oshmaydi)
-- (supabase-migration-34-mijoz-haqi.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 34-MIGRATSIYA (v24.5): MIJOZ HAQI (ORTIQCHA TO'LOV) VA SAVDO TO'LOVINI SERVERDA TEKSHIRISH
-- Egasi tasdiqlagan qoida (2026-10-14):
--   • Savdoda olingan summa chekdan KO'P bo'lsa — mijoz majburiy; ortiqchasi avval mijozning mavjud
--     qarzidan ayiriladi, qolgani mijozning HAQI (oldindan to'lovi) bo'lib qoladi. Pul kassaga to'liq tushadi.
--   • Haq keyingi savdoda «Haqidan ishlatish» bilan sarflanadi (haqdan ortiq emas).
--   • Mijoz qarzi qoidalari (qarz manfiy bo'lmaydi) o'zgarmaydi — haq ALOHIDA hisob (ta'minotchi zakladi kabi).
--   • Haqdan to'langan savdo o'chirilsa — haq to'liq qaytadi, kassadan faqat naqd qismi chiqadi.
--     Bunday savdoni tahrirlash taqiqlanadi (qaytarish va o'chirish ishlaydi).
-- Xavfsizlik tuzatishi: savdoda «to'langan» summa endi kassaga tushum + haqdan oshmasligi serverda tekshiriladi
-- (avval brauzer yuborgan paidUsd kassaga tushumsiz ham qabul qilinardi — qarz kam yozilishi mumkin edi).
-- Hammasi bitta tranzaksiyada; takror so'rov ikki marta yozilmaydi. Faqat qo'shadi; mavjud ma'lumot o'zgarmaydi;
-- qayta ishga tushirish xavfsiz. Talab: 24, 27, 31, 32.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.ledger_ops') is null or not exists (select 1 from pg_proc where proname = '_cust_debt_move')
     or not exists (select 1 from pg_proc where proname = 'sale_checkout_guarded') or not exists (select 1 from pg_proc where proname = 'sale_void_guarded')
     or to_regclass('public.fw_dealer_revisions') is null then
    raise exception '34-migratsiya: avval 24, 27, 31 va 32-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Mijoz haqi (so'm) va o'zgarmas jurnal ───────────────────────────
create table if not exists public.customer_credit_balances (
  filial text not null,
  customer_local_id bigint not null,
  credit_uzs numeric(20,2) not null default 0,
  updated_at timestamp with time zone not null default now(),
  primary key (filial, customer_local_id),
  constraint customer_credit_balances_nonneg check (credit_uzs >= 0)
);
create table if not exists public.customer_credit_ledger (
  id bigint generated always as identity primary key,
  created_at timestamp with time zone not null default now(),
  filial text not null,
  customer_local_id bigint not null,
  kind text not null,
  delta_uzs numeric(20,2) not null,
  balance_after numeric(20,2) not null,
  op_key text not null,
  ref_type text,
  ref_id text,
  note text,
  staff_id bigint,
  staff_name text,
  constraint customer_credit_ledger_kind_chk check (kind in ('overpay','apply','void_restore','refund','adjust')),
  constraint customer_credit_ledger_amt_chk check (delta_uzs <> 0 and balance_after >= 0),
  constraint customer_credit_ledger_len_chk check (length(op_key) <= 160 and coalesce(length(note),0) <= 500
    and coalesce(length(staff_name),0) <= 200 and coalesce(length(ref_id),0) <= 100 and length(filial) <= 40),
  constraint customer_credit_ledger_op_uq unique (filial, op_key, kind)
);
create index if not exists idx_cust_credit_ledger_party on public.customer_credit_ledger (filial, customer_local_id, id desc);

-- Savdoda haqdan foydalanish (o'chirilsa — qaytariladi; tahrir taqiqlanadi)
create table if not exists public.sale_credit_uses (
  filial text not null,
  sale_local_id text not null,
  customer_local_id bigint not null,
  credit_uzs numeric(20,2) not null,
  restored_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  primary key (filial, sale_local_id),
  constraint sale_credit_uses_amt_chk check (credit_uzs > 0)
);

create or replace function public._fw_credit_guard()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if tg_table_name in ('customer_credit_balances','sale_credit_uses') and coalesce(current_setting('fw.credit_move', true), '') = '1' and tg_op <> 'DELETE' then
    return new;
  end if;
  raise exception 'HAQ: mijoz haqi faqat savdo amallari orqali o''zgaradi (jurnal o''zgarmas)' using errcode = 'P0001';
end;
$$;
create or replace trigger customer_credit_balances_guard before insert or update or delete on public.customer_credit_balances
  for each row execute function public._fw_credit_guard();
create or replace trigger sale_credit_uses_guard before insert or update or delete on public.sale_credit_uses
  for each row execute function public._fw_credit_guard();
create or replace trigger customer_credit_ledger_immutable before update or delete on public.customer_credit_ledger
  for each row execute function public._fw_credit_guard();
create or replace trigger customer_credit_ledger_no_truncate before truncate on public.customer_credit_ledger
  for each statement execute function public._fw_credit_guard();

alter table public.customer_credit_balances enable row level security;
alter table public.customer_credit_ledger enable row level security;
alter table public.sale_credit_uses enable row level security;
revoke all on public.customer_credit_balances, public.customer_credit_ledger, public.sale_credit_uses from anon, authenticated;
grant select, insert, update on public.customer_credit_balances, public.sale_credit_uses to service_role;
grant select, insert on public.customer_credit_ledger to service_role;
grant usage on sequence public.customer_credit_ledger_id_seq to service_role;

-- ── 2. Kassa amal turi: ortiqcha to'lov (mijoz haqi / qarz to'lovi) ────
alter table public.cashbox_ledger drop constraint if exists cashbox_ledger_kind_chk;
alter table public.cashbox_ledger add constraint cashbox_ledger_kind_chk check (op_kind in (
  'opening','sale','sale_fix','manual_in','manual_out','move','exchange','expense','expense_fix','salary',
  'cust_debt_pay','supp_pay','kirim_pay','dealer_pay','home_withdrawal','branch_to_firma','firma_to_branch','reset_zero',
  'branch_loan_in','branch_loan_repay','supp_advance','cust_credit'));

-- ── 3. Haq harakati (yagona yo'l) ──────────────────────────────────────
create or replace function public._cust_credit_move(
  p_filial text, p_cust bigint, p_delta numeric, p_kind text, p_op_key text,
  p_ref_type text default null, p_ref_id text default null, p_note text default null,
  p_staff_id bigint default null, p_staff_name text default null)
 returns numeric
 language plpgsql
 set search_path = ''
as $$
declare
  v_bal numeric;
  v_new numeric;
begin
  if coalesce(p_filial, '') = '' or p_cust is null or p_cust <= 0 then raise exception 'HAQ: mijoz noto''g''ri' using errcode = 'P0001'; end if;
  if p_delta is null or p_delta = 'NaN'::numeric or p_delta = 0 or abs(p_delta) > 1000000000000 then
    raise exception 'HAQ: summa noto''g''ri' using errcode = 'P0001';
  end if;
  perform set_config('fw.credit_move', '1', true);
  insert into public.customer_credit_balances (filial, customer_local_id, credit_uzs) values (p_filial, p_cust, 0)
    on conflict (filial, customer_local_id) do nothing;
  select credit_uzs into v_bal from public.customer_credit_balances where filial = p_filial and customer_local_id = p_cust for update;
  v_new := round(coalesce(v_bal, 0) + p_delta, 2);
  if v_new < 0 then
    raise exception 'HAQ: mijoz haqi yetarli emas (bor: % so''m, kerak: % so''m)', round(coalesce(v_bal, 0)), round(-p_delta) using errcode = 'P0001';
  end if;
  update public.customer_credit_balances set credit_uzs = v_new, updated_at = now() where filial = p_filial and customer_local_id = p_cust;
  insert into public.customer_credit_ledger (filial, customer_local_id, kind, delta_uzs, balance_after, op_key, ref_type, ref_id, note, staff_id, staff_name)
  values (p_filial, p_cust, p_kind, round(p_delta, 2), v_new, left(p_op_key, 160), left(p_ref_type, 40), left(p_ref_id, 100), left(p_note, 500), p_staff_id, left(p_staff_name, 200));
  perform set_config('fw.credit_move', '', true);
  return v_new;
end;
$$;

-- ── 4. SAVDO (v34): to'lov tekshiruvi + haqdan foydalanish + ortiqcha to'lov ──
-- p_overpay: {box_id, amount_native} — kassaga tushgan, chek summasidan ORTIQ pul (mijoz majburiy)
-- p_credit_use_uzs: mijoz haqidan shu savdoga ishlatiladigan summa (so'm)
create or replace function public.sale_checkout_v34(
  p_filial text, p_op_key text, p_sale jsonb, p_box_payments jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_loss_ack boolean default false,
  p_overpay jsonb default null, p_credit_use_uzs numeric default 0)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_res jsonb;
  v_cust bigint;
  v_rate numeric;
  v_paid numeric;
  v_cash_usd numeric := 0;
  v_credit numeric := round(coalesce(p_credit_use_uzs, 0), 2);
  v_credit_usd numeric := 0;
  v_bp jsonb;
  v_cur text;
  v_amt numeric;
  v_box int;
  v_local text;
  v_inv text;
  v_ov_box int;
  v_ov_amt numeric;
  v_ov_cur text;
  v_ov_uzs numeric;
  v_debt numeric;
  v_to_debt numeric;
  v_rows jsonb;
  v_bal jsonb;
begin
  v_cust := case when coalesce(p_sale->>'custId', '') ~ '^[0-9]{1,18}$' and (p_sale->>'custId')::numeric > 0 then (p_sale->>'custId')::bigint end;
  v_local := p_sale->>'localId';
  -- Takror so'rov — birinchi natija + mijozning joriy qarzi/haqi
  if exists (select 1 from public.ledger_ops where filial = p_filial and op_key = p_op_key) then
    v_res := public.sale_checkout_guarded(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name, p_role, p_loss_ack);
    if v_cust is not null then
      v_res := v_res || jsonb_build_object(
        'custDebtUzs', coalesce((select debt from public.customer_balances where filial = p_filial and customer_local_id = v_cust), 0),
        'custCreditUzs', coalesce((select credit_uzs from public.customer_credit_balances where filial = p_filial and customer_local_id = v_cust), 0));
    end if;
    return v_res;
  end if;

  if v_credit < 0 or v_credit > 1000000000000 then raise exception 'HAQ: summa noto''g''ri' using errcode = 'P0001'; end if;
  if (v_credit > 0 or p_overpay is not null) and v_cust is null then
    raise exception 'SAVDO: ortiqcha to''lov yoki haqdan foydalanish uchun mijoz tanlanishi shart' using errcode = 'P0001';
  end if;
  v_rate := public._fw_rate();

  -- To'langan summa = kassaga tushum + haqdan; ortig'i qabul qilinmaydi (qarz kam yozilmasin)
  if p_box_payments is not null and jsonb_typeof(p_box_payments) = 'array' then
    for v_bp in select * from jsonb_array_elements(p_box_payments) loop
      continue when coalesce(v_bp->>'box_id', '') !~ '^[0-9]{1,9}$';
      v_amt := public._fw_num(v_bp->>'amount_native');
      continue when v_amt <= 0;
      select currency into v_cur from public.cashbox_balances where filial = p_filial and box_local_id = (v_bp->>'box_id')::int;
      v_cur := coalesce(v_cur, case when v_bp->>'currency' in ('USD','UZS') then v_bp->>'currency' end, 'UZS');
      v_cash_usd := v_cash_usd + case when v_cur = 'USD' then v_amt else v_amt / v_rate end;
    end loop;
  end if;
  v_credit_usd := v_credit / v_rate;
  v_paid := public._fw_num(p_sale->>'paidUsd');
  if v_paid > v_cash_usd + v_credit_usd + greatest(0.02, (v_cash_usd + v_credit_usd) * 0.005) then
    raise exception 'SAVDO: to''langan summa (% $) kassaga tushumdan (% $) oshib ketdi', round(v_paid, 2), round(v_cash_usd + v_credit_usd, 2) using errcode = 'P0001';
  end if;

  -- Haqdan foydalanish — savdodan OLDIN tekshiriladi (yetmasa hech narsa yozilmaydi)
  if v_credit > 0 then
    perform public._cust_credit_move(p_filial, v_cust, -v_credit, 'apply', p_op_key, 'sale', p_sale->>'inv',
                                     'Savdoda haqdan: ' || coalesce(p_sale->>'inv', ''), p_staff_id, p_staff_name);
  end if;

  v_res := public.sale_checkout_guarded(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name, p_role, p_loss_ack);
  v_local := v_res->>'localId';
  v_inv := v_res->>'inv';

  -- v24.5 audit (P1): haqdan ishlatiladigan summa savdoning kassadan to'lanmagan qismidan oshmasin. Avval chegarasiz edi:
  -- 100 000 so'mlik savdoga 1 000 000 so'm haq yuborilsa, haq to'liq yechilar, ortig'i hech qayerga yozilmay yo'qolardi.
  -- Xato bo'lsa butun tranzaksiya (haq yechimi va savdo) qaytariladi.
  if v_credit > 0 and v_credit_usd > greatest(0, coalesce((v_res->>'totalUsd')::numeric, 0) - v_cash_usd)
                                      + greatest(0.02, coalesce((v_res->>'totalUsd')::numeric, 0) * 0.005) then
    raise exception 'HAQ: ishlatiladigan haq (% $) savdoning to''lanmagan qismidan (% $) ko''p', round(v_credit_usd, 2),
      round(greatest(0, coalesce((v_res->>'totalUsd')::numeric, 0) - v_cash_usd), 2) using errcode = 'P0001';
  end if;

  if v_credit > 0 then
    -- O'chirishda kassadan faqat NAQD qism chiqishi uchun to'lov aralash (kassa qatorlari) ko'rinishida saqlanadi
    select coalesce(jsonb_agg(jsonb_build_object('boxId', (e->>'box_id')::int, 'amount', public._fw_num(e->>'amount_native'))), '[]'::jsonb)
      into v_rows from jsonb_array_elements(coalesce(p_box_payments, '[]'::jsonb)) e
     where coalesce(e->>'box_id', '') ~ '^[0-9]{1,9}$' and public._fw_num(e->>'amount_native') > 0;
    update public.sales set pay_type = 'mixed', box_id = null, mixed_rows = v_rows
     where filial = p_filial and local_id = v_local;
    perform set_config('fw.credit_move', '1', true);
    insert into public.sale_credit_uses (filial, sale_local_id, customer_local_id, credit_uzs) values (p_filial, v_local, v_cust, v_credit);
    perform set_config('fw.credit_move', '', true);
  end if;

  -- Ortiqcha to'lov: kassaga kirim → avval mijoz qarzi, qolgani — haq
  if p_overpay is not null and jsonb_typeof(p_overpay) = 'object' then
    if coalesce(p_overpay->>'box_id', '') !~ '^[0-9]{1,9}$' then raise exception 'SAVDO: ortiqcha to''lov kassasi noto''g''ri' using errcode = 'P0001'; end if;
    v_ov_box := (p_overpay->>'box_id')::int;
    v_ov_amt := round(public._fw_num(p_overpay->>'amount_native'), 2);
    if v_ov_amt > 0 then
      select currency into v_ov_cur from public.cashbox_balances where filial = p_filial and box_local_id = v_ov_box;
      if v_ov_cur is null then raise exception 'CASHBOX: kassa topilmadi (kassa %)', v_ov_box using errcode = 'P0001'; end if;
      v_ov_uzs := round(case when v_ov_cur = 'USD' then v_ov_amt * v_rate else v_ov_amt end, 2);
      if v_ov_uzs > greatest(100000000, coalesce((v_res->>'totalUsd')::numeric, 0) * v_rate * 10) then
        raise exception 'SAVDO: ortiqcha summa haddan katta — tekshiring' using errcode = 'P0001';
      end if;
      perform public._cb_move(p_filial, v_ov_box, v_ov_cur, 'in', v_ov_amt, 'cust_credit', p_op_key || ':ov', 'sale:' || v_local,
                              null, 'sale', v_inv, 'Ortiqcha to''lov (mijoz) — ' || coalesce(v_inv, ''), p_staff_id, p_staff_name);
      select coalesce(debt, 0) into v_debt from public.customer_balances where filial = p_filial and customer_local_id = v_cust;
      v_to_debt := least(coalesce(v_debt, 0), v_ov_uzs);
      if v_to_debt > 0 then
        perform public._cust_debt_move(p_filial, v_cust, -v_to_debt, 'strict', 'payment', p_op_key || ':ovd', p_op_key, 'sale', v_inv,
                                       'Ortiqcha to''lovdan qarz uzildi: ' || coalesce(v_inv, ''), p_staff_id, p_staff_name);
      end if;
      if v_ov_uzs - v_to_debt > 0.004 then
        perform public._cust_credit_move(p_filial, v_cust, v_ov_uzs - v_to_debt, 'overpay', p_op_key, 'sale', v_inv,
                                         'Ortiqcha to''lov: ' || coalesce(v_inv, ''), p_staff_id, p_staff_name);
      end if;
    end if;
  end if;

  if v_cust is not null then
    v_res := v_res || jsonb_build_object(
      'custDebtUzs', coalesce((select debt from public.customer_balances where filial = p_filial and customer_local_id = v_cust), 0),
      'custCreditUzs', coalesce((select credit_uzs from public.customer_credit_balances where filial = p_filial and customer_local_id = v_cust), 0));
  end if;
  if v_ov_box is not null then
    v_bal := coalesce(v_res->'balances', '{}'::jsonb) || public._cb_balances_map(p_filial, array[v_ov_box]);
    v_res := v_res || jsonb_build_object('balances', v_bal);
  end if;
  return v_res;
end;
$$;

-- ── 5. O'chirish (v34): haqdan to'langan qism mijozga qaytadi ─────────
create or replace function public.sale_void_v34(
  p_filial text, p_op_key text, p_sale_local_id text, p_batch_ids jsonb, p_meta jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_can_others boolean default false)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_res jsonb;
  u public.sale_credit_uses;
begin
  v_res := public.sale_void_guarded(p_filial, p_op_key, p_sale_local_id, p_batch_ids, p_meta, p_staff_id, p_staff_name, p_role, p_can_others);
  select * into u from public.sale_credit_uses where filial = p_filial and sale_local_id = p_sale_local_id for update;
  if found and u.restored_at is null then
    perform public._cust_credit_move(p_filial, u.customer_local_id, u.credit_uzs, 'void_restore', p_op_key, 'sale', p_sale_local_id,
                                     'Savdo o''chirildi — haq qaytdi', p_staff_id, p_staff_name);
    perform set_config('fw.credit_move', '1', true);
    update public.sale_credit_uses set restored_at = now() where filial = p_filial and sale_local_id = p_sale_local_id;
    perform set_config('fw.credit_move', '', true);
    v_res := v_res || jsonb_build_object('creditRestoredUzs', u.credit_uzs, 'custId', u.customer_local_id,
      'custCreditUzs', (select credit_uzs from public.customer_credit_balances where filial = p_filial and customer_local_id = u.customer_local_id));
  end if;
  return v_res;
end;
$$;

-- ── 6. Funksiya huquqlari (faqat server) ───────────────────────────────
revoke all on function public._fw_credit_guard() from public, anon, authenticated;
revoke all on function public._cust_credit_move(text, bigint, numeric, text, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.sale_checkout_v34(text, text, jsonb, jsonb, bigint, text, text, boolean, jsonb, numeric) from public, anon, authenticated;
revoke all on function public.sale_void_v34(text, text, text, jsonb, jsonb, bigint, text, text, boolean) from public, anon, authenticated;
grant execute on function public.sale_checkout_v34(text, text, jsonb, jsonb, bigint, text, text, boolean, jsonb, numeric) to service_role;
grant execute on function public.sale_void_v34(text, text, text, jsonb, jsonb, bigint, text, text, boolean) to service_role;

comment on table public.customer_credit_balances is '34-migratsiya: mijoz haqi (ortiqcha to''lov, oldindan to''lov), so''m — qarzdan alohida';
comment on table public.customer_credit_ledger is '34-migratsiya: mijoz haqi jurnali (ortiqcha to''lov, savdoda ishlatish, o''chirishda qaytish). O''zgarmas';
comment on table public.sale_credit_uses is '34-migratsiya: savdoda haqdan foydalanish (o''chirilsa qaytariladi; bunday savdo tahrirlanmaydi)';

-- ────────────────────────────────────────────────────────────────────
-- 19. 35-migratsiya: DILLER OMBORI VA DILLER SAVDOSI — serverda, bitta tranzaksiyada (jo'natish/buyurtma tasdig'i, qaytarish, admin diller savdosi; v23.10.2 dagi 31 dan)
-- (supabase-migration-35-diller-ombor-atomik.sql bilan AYNAN bir xil)
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════
-- 35-MIGRATSIYA (v24.5; v23.10.2 dagi 31-migratsiyadan ko'chirildi): DILLER OMBORI VA DILLER SAVDOSI —
--                      SERVERDA, BITTA TRANZAKSIYADA («diller ombori atomik»)
-- Muammo: dillerga jo'natish, buyurtmani tasdiqlash, dillerdan qaytarish va admin yozadigan diller savdosi
-- brauzer boshqaradigan bir nechta alohida so'rov edi: firma omboridan chiqarish → diller qoldig'ini o'qish →
-- yangi qoldiqni MUTLAQ qiymat sifatida yozish → harakat → total_shipped / qarz MUTLAQ qiymat.
--   • o'rtadagi xatoda tovar firma omboridan chiqib, diller omboriga tushmay qolardi;
--   • ikki xodim bir vaqtda — ikkalasi bir xil eski qoldiqni o'qib, biri yo'qolardi (lost update);
--   • diller savdosida (Promise.all) qoldiq yozuvi va savdo tekshiruvi tartibi tasodifiy edi.
-- Yechim: uchta funksiya — har biri BITTA tranzaksiyada, diller qatori qulflanadi, qoldiq/qarz SERVERDA
-- hisoblanadi (brauzer faqat amalni so'raydi), takroriy so'rov (bir xil kalit) ikki marta yozilmaydi (ledger_ops).
--   dealer_ship_atomic        — firma omboridan FIFO (stock_debt_op) + diller ombori + harakat + total_shipped
--                               (+ ixtiyoriy: buyurtmani 'pending' → 'approved' — ikki marta tasdiqlab bo'lmaydi)
--   dealer_return_atomic      — diller omboridan ayirish (qoldiqdan oshmaydi) + harakat; sotiladigan holat
--                               (Yangi / Yaxshi) — firma omboriga yangi partiya (stock_debt_op batches_create)
--   dealer_sale_record_atomic — ADMIN diller savdosini yozadi: qoldiq tekshiruvi, dealer_sales (source = null —
--                               oddiy savdo), qarz = (Σ miqdor×narx) × (1 − komissiya%), total_sold, ballar
-- v24.5 bilan moslik:
--   • record_dealer_sale (diller portali, 31-migratsiyadagi optom narxdan −10% chegarasi) — O'ZGARTIRILMAYDI.
--   • Diller reviziyasi (32: dealer_revision_decide) o'zgarmaydi; bu funksiyalar ham dealers → dealer_stock tartibida
--     qulflaydi. Reviziyadan keyin jo'natish/qaytarish/savdo bo'lsa — reviziya tasdig'i REV_STALE bilan rad etiladi
--     (32 dagi qoida: qoldiq o'zgargan — qayta reviziya kerak).
--   • ledger_ops amal turlari — 33-migratsiyadagi TO'LIQ ro'yxat (27, 28, 29, 33) + 3 ta diller amali.
--     34 ledger_ops turlarini o'zgartirmaydi (faqat cashbox_ledger) — bu migratsiya kassa turlariga tegmaydi.
-- Faqat qo'shadi; ma'lumot o'chirmaydi; qayta ishga tushirish xavfsiz. Talab: 27 (stock_debt_op, ledger_ops) va 34.
-- Funksiyalar faqat service_role (Netlify `dealer-ops`) uchun — brauzer rollari chaqira olmaydi.
-- Qo'shimcha (7-bo'lim): 10 ta eski funksiyaga qat'iy search_path (Supabase xavfsizlik ogohlantirishi).
-- DIQQAT: 27, 28, 29 yoki 33 qayta qo'llansa — ledger_ops amal turlari qaytadi; oxirida 35 ni ham qayta qo'llang
-- (diller amallari yozilgan bazada ular qayta qo'llanmaydi — CHECK xatosi bilan to'xtaydi, hech narsa o'zgarmaydi).
-- ════════════════════════════════════════════════════════════════════

-- ── 0. Bog'liqlik ──────────────────────────────────────────────────────
do $$ begin
  if to_regclass('public.ledger_ops') is null or not exists (select 1 from pg_proc where proname = 'stock_debt_op') then
    raise exception '35-migratsiya: avval 27-migratsiyani qo''llang';
  end if;
  if to_regclass('public.customer_credit_balances') is null or not exists (select 1 from pg_proc where proname = 'sale_checkout_v34')
     or not exists (select 1 from pg_proc where proname = 'supplier_advance_apply') then
    raise exception '35-migratsiya: avval 33 va 34-migratsiyalarni qo''llang';
  end if;
end $$;

-- ── 1. Amal turlari (33-migratsiyadagi to'liq ro'yxat + diller amallari) ──
alter table public.ledger_ops drop constraint if exists ledger_ops_kind_chk;
alter table public.ledger_ops add constraint ledger_ops_kind_chk check (kind in ('sale','sale_return','sale_void','sale_edit','cust_set','supp_set',
  'batches_create','batch_edit','batch_delete','batch_arrive','revision','stock_out','firma_supp_pay',
  'writeoff','writeoff_cancel','b2b_ship','b2b_receive','b2b_ack','b2b_restock','supp_advance','supp_advance_apply',
  'dealer_ship','dealer_return','dealer_sale'));

-- ── 2. Yordamchi: diller holati (javob uchun) va ichki amal partiyalari ─
create or replace function public._dealer_json(d public.dealers)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object('id', d.id, 'debt', d.debt_usd, 'totalShipped', d.total_shipped_usd, 'totalSold', d.total_sold_usd,
                            'totalPaid', d.total_paid_usd, 'points', d.points);
$$;

create or replace function public._ledger_op_batch_ids(p_filial text, p_op_key text)
 returns bigint[]
 language sql
 stable
 set search_path = ''
as $$
  select coalesce(array(select jsonb_array_elements_text(coalesce(result->'_ids'->'b', '[]'::jsonb))::bigint
                          from public.ledger_ops where filial = p_filial and op_key = p_op_key), '{}');
$$;

create or replace function public._dealer_lock(p_filial text, p_dealer_id bigint)
 returns public.dealers
 language plpgsql
 set search_path = ''
as $$
declare d public.dealers;
begin
  select * into d from public.dealers where id = p_dealer_id for update;
  if not found or coalesce(d.filial, 'baza') <> p_filial then
    raise exception 'LEDGER: diller topilmadi' using errcode = 'P0001';
  end if;
  if d.active is false then raise exception 'LEDGER: diller faol emas' using errcode = 'P0001'; end if;
  return d;
end;
$$;

-- ── 3. Dillerga jo'natish (va buyurtmani tasdiqlash) ──────────────────
-- p_items: [{pid, qty, sku, name}] — sku/name faqat yozuv uchun; tannarx FIFO bo'yicha SERVERDA
create or replace function public.dealer_ship_atomic(
  p_filial text, p_op_key text, p_dealer_id bigint, p_items jsonb, p_order_id bigint,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  d public.dealers;
  v_out jsonb;
  x jsonb;
  v_lbl jsonb;
  v_pid bigint;
  v_qty numeric;
  v_cost numeric;
  v_total numeric := 0;
  v_ds public.dealer_stock;
  v_items jsonb := '[]'::jsonb;
  v_order public.dealer_orders;
  v_pids bigint[];
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'dealer_ship');
  if v_r is not null then return v_r; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 500 then
    raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) e
              where coalesce(e->>'pid', '') !~ '^[0-9]{1,18}$' or public._fw_num(e->>'qty') <= 0 or public._fw_num(e->>'qty') > 1000000) then
    raise exception 'LEDGER: mahsulot qatori noto''g''ri' using errcode = 'P0001';
  end if;
  if (select count(distinct e->>'pid') from jsonb_array_elements(p_items) e) <> jsonb_array_length(p_items) then
    raise exception 'LEDGER: bir mahsulot ikki marta yozilgan' using errcode = 'P0001';
  end if;
  d := public._dealer_lock(p_filial, p_dealer_id);

  if p_order_id is not null then
    select * into v_order from public.dealer_orders where id = p_order_id for update;
    if not found or v_order.dealer_id <> p_dealer_id then raise exception 'LEDGER: buyurtma topilmadi' using errcode = 'P0001'; end if;
    if v_order.status <> 'pending' then
      raise exception 'LEDGER: buyurtma allaqachon ko''rib chiqilgan (%)', v_order.status using errcode = 'P0001';
    end if;
    v_pids := array(select public._fw_num(i->>'pid')::bigint from jsonb_array_elements(case when jsonb_typeof(v_order.items) = 'array' then v_order.items else '[]'::jsonb end) i);
    if exists (select 1 from jsonb_array_elements(p_items) e where (e->>'pid')::bigint <> all(v_pids)) then
      raise exception 'LEDGER: buyurtmada yo''q mahsulot' using errcode = 'P0001';
    end if;
    update public.dealer_orders set status = 'approved', resolved_at = now(),
           items = (select jsonb_agg(jsonb_build_object('pid', (e->>'pid')::bigint, 'sku', left(e->>'sku', 80), 'name', left(e->>'name', 200),
                                                        'qty', public._fw_num(e->>'qty'))) from jsonb_array_elements(p_items) e)
     where id = p_order_id;
  end if;

  -- Firma ombori: FIFO, yetmasa — butun amal rad etiladi (diller ombori ham, buyurtma ham o'zgarmaydi)
  v_out := public.stock_debt_op(p_filial, p_op_key || ':out', 'stock_out',
             jsonb_build_object('reason', 'dealer', 'dealerId', p_dealer_id::text,
               'items', (select jsonb_agg(jsonb_build_object('pid', (e->>'pid')::bigint, 'qty', public._fw_num(e->>'qty'))) from jsonb_array_elements(p_items) e)),
             p_staff_id, p_staff_name);

  for x in select * from jsonb_array_elements(v_out->'items') loop
    v_pid := (x->>'pid')::bigint;
    v_qty := (x->>'qty')::numeric;
    v_cost := (x->>'cost')::numeric;                      -- shu miqdorning haqiqiy FIFO tannarxi (jami)
    select e into v_lbl from jsonb_array_elements(p_items) e where (e->>'pid')::bigint = v_pid limit 1;
    insert into public.dealer_stock (dealer_id, pid, sku, name, qty, avg_cost_usd, updated_at)
    values (p_dealer_id, v_pid, left(v_lbl->>'sku', 80), left(v_lbl->>'name', 300), v_qty, round(v_cost / v_qty, 6), now())
    on conflict (dealer_id, pid) do update set
      avg_cost_usd = case when public.dealer_stock.qty + excluded.qty > 0
                          then round((public.dealer_stock.qty * public.dealer_stock.avg_cost_usd + v_cost) / (public.dealer_stock.qty + excluded.qty), 6)
                          else excluded.avg_cost_usd end,
      qty = public.dealer_stock.qty + excluded.qty,
      sku = coalesce(excluded.sku, public.dealer_stock.sku), name = coalesce(excluded.name, public.dealer_stock.name), updated_at = now()
    returning * into v_ds;
    insert into public.dealer_stock_moves (dealer_id, type, pid, sku, name, qty, cost_usd, reason)
    values (p_dealer_id, 'send', v_pid, left(v_lbl->>'sku', 80), left(v_lbl->>'name', 300), v_qty, round(v_cost / v_qty, 6),
            case when p_order_id is not null then 'Buyurtma #' || p_order_id end);
    v_total := v_total + v_cost;
    v_items := v_items || jsonb_build_object('pid', v_pid, 'qty', v_qty, 'costUsd', round(v_cost / v_qty, 6), 'firstCost', (x->>'firstCost')::numeric,
                                             'dealerQty', v_ds.qty, 'dealerAvgCostUsd', v_ds.avg_cost_usd);
  end loop;
  update public.dealers set total_shipped_usd = round(total_shipped_usd + v_total, 4) where id = p_dealer_id returning * into d;

  return public._ledger_op_finish(p_filial, p_op_key, 'dealer_ship',
    jsonb_build_object('ok', true, 'kind', 'dealer_ship', 'items', v_items, 'totalCostUsd', round(v_total, 4),
                       'orderId', p_order_id, 'dealer', public._dealer_json(d)),
    '{}', '{}', public._ledger_op_batch_ids(p_filial, p_op_key || ':out'), p_staff_id, p_staff_name);
end;
$$;

-- ── 4. Dillerdan qaytarish ─────────────────────────────────────────────
-- p_items: [{pid, qty, condition, reason, localId, bno, sku, name}] — localId: sotiladigan holatdagi
-- qaytgan tovar uchun firma omboridagi yangi partiya ID'si (brauzer barqaror kalit beradi)
create or replace function public.dealer_return_atomic(
  p_filial text, p_op_key text, p_dealer_id bigint, p_items jsonb,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  d public.dealers;
  e jsonb;
  v_pid bigint;
  v_qty numeric;
  v_ds public.dealer_stock;
  v_sellable boolean;
  v_batches jsonb := '[]'::jsonb;
  v_items jsonb := '[]'::jsonb;
  v_bids bigint[] := '{}';
  v_total numeric := 0;
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'dealer_return');
  if v_r is not null then return v_r; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 500 then
    raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
  end if;
  d := public._dealer_lock(p_filial, p_dealer_id);
  for e in select * from jsonb_array_elements(p_items) order by public._fw_num(value->>'pid') loop
    if coalesce(e->>'pid', '') !~ '^[0-9]{1,18}$' or public._fw_num(e->>'qty') <= 0 or public._fw_num(e->>'qty') > 1000000 then
      raise exception 'LEDGER: mahsulot qatori noto''g''ri' using errcode = 'P0001';
    end if;
    v_pid := (e->>'pid')::bigint;
    v_qty := public._fw_num(e->>'qty');
    select * into v_ds from public.dealer_stock where dealer_id = p_dealer_id and pid = v_pid for update;
    if not found or v_ds.qty < v_qty then
      raise exception 'LEDGER: dillerda yetarli qoldiq yo''q (pid=%, bor: %, so''ralgan: %)', v_pid, coalesce(v_ds.qty, 0), v_qty using errcode = 'P0001';
    end if;
    update public.dealer_stock set qty = qty - v_qty, updated_at = now() where id = v_ds.id returning * into v_ds;
    insert into public.dealer_stock_moves (dealer_id, type, pid, sku, name, qty, cost_usd, reason, condition)
    values (p_dealer_id, 'return', v_pid, coalesce(v_ds.sku, left(e->>'sku', 80)), coalesce(v_ds.name, left(e->>'name', 300)), v_qty, v_ds.avg_cost_usd,
            left(e->>'reason', 300), left(e->>'condition', 40));
    v_sellable := coalesce(e->>'condition', '') in ('Yangi', 'Yaxshi');
    if v_sellable then
      if coalesce(e->>'localId', '') !~ '^[0-9A-Za-z_.:-]{1,64}$' then
        raise exception 'LEDGER: qaytgan partiya ID noto''g''ri' using errcode = 'P0001';
      end if;
      v_batches := v_batches || jsonb_build_object('localId', e->>'localId', 'pid', v_pid, 'qty', v_qty, 'costUsd', v_ds.avg_cost_usd,
                     'meta', jsonb_build_object('bno', left(e->>'bno', 20), 'origin', 'Dillerdan qaytdi (' || left(e->>'condition', 40) || ')', 'date', current_date::text));
    end if;
    v_total := v_total + v_qty * v_ds.avg_cost_usd;
    v_items := v_items || jsonb_build_object('pid', v_pid, 'qty', v_qty, 'costUsd', v_ds.avg_cost_usd, 'sellable', v_sellable,
                                             'dealerQty', v_ds.qty, 'dealerAvgCostUsd', v_ds.avg_cost_usd);
  end loop;
  if jsonb_array_length(v_batches) > 0 then
    perform public.stock_debt_op(p_filial, p_op_key || ':in', 'batches_create',
              jsonb_build_object('reason', 'dealer_return', 'batches', v_batches), p_staff_id, p_staff_name);
    v_bids := public._ledger_op_batch_ids(p_filial, p_op_key || ':in');
  end if;
  return public._ledger_op_finish(p_filial, p_op_key, 'dealer_return',
    jsonb_build_object('ok', true, 'kind', 'dealer_return', 'items', v_items, 'totalCostUsd', round(v_total, 4), 'dealer', public._dealer_json(d)),
    '{}', '{}', v_bids, p_staff_id, p_staff_name);
end;
$$;

-- ── 5. Admin diller savdosini yozadi ───────────────────────────────────
-- p_items: [{pid, qty, priceUsd, sku, name}], p_pct — diller xizmat haqi % (0–100, xodim belgilaydi)
-- Qarz = Σ(miqdor×narx) × (1 − p_pct/100); ballar — mahsulot pointPct (app_data) va Sozlamalar
-- (pointUsdValue, pointRoundStep) bo'yicha — brauzerdagi calcDealerPoints bilan bir xil formula.
-- v24.5: dealer_sales.source (32) yozilmaydi — null = oddiy savdo (reviziya yozuvlari 'revision_*' bilan ajralib turadi).
-- Bu yo'l faqat xodim («dillerlar.manage») uchun; dillerning o'zi sotishi record_dealer_sale (−10% chegarasi) orqali qoladi.
create or replace function public.dealer_sale_record_atomic(
  p_filial text, p_op_key text, p_dealer_id bigint, p_items jsonb, p_pct numeric,
  p_staff_id bigint default null, p_staff_name text default null)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_r jsonb;
  d public.dealers;
  e jsonb;
  v_pid bigint;
  v_qty numeric;
  v_price numeric;
  v_ds public.dealer_stock;
  v_main jsonb;
  v_usd_val numeric;
  v_step numeric;
  v_ppct numeric;
  v_line numeric;
  v_total numeric := 0;
  v_profit numeric := 0;
  v_points numeric := 0;
  v_owed numeric;
  v_items jsonb := '[]'::jsonb;
begin
  v_r := public._ledger_op_replay(p_filial, p_op_key, 'dealer_sale');
  if v_r is not null then return v_r; end if;
  if p_pct is null or p_pct = 'NaN'::numeric or p_pct < 0 or p_pct > 100 then
    raise exception 'LEDGER: xizmat haqi foizi noto''g''ri' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 500 then
    raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
  end if;
  d := public._dealer_lock(p_filial, p_dealer_id);
  select data into v_main from public.app_data where id = 'main';
  v_usd_val := coalesce(public._fw_num(v_main->'settings'->>'pointUsdValue'), 0);
  if v_main->'settings'->>'pointUsdValue' is null then v_usd_val := 2; end if;
  v_step := coalesce(nullif(public._fw_num(v_main->'settings'->>'pointRoundStep'), 0), 1);
  for e in select * from jsonb_array_elements(p_items) order by public._fw_num(value->>'pid') loop
    v_qty := public._fw_num(e->>'qty');
    v_price := public._fw_num(e->>'priceUsd');
    if coalesce(e->>'pid', '') !~ '^[0-9]{1,18}$' or v_qty <= 0 or v_qty > 1000000 or v_price <= 0 or v_price > 1000000000 then
      raise exception 'LEDGER: mahsulot qatori noto''g''ri' using errcode = 'P0001';
    end if;
    v_pid := (e->>'pid')::bigint;
    select * into v_ds from public.dealer_stock where dealer_id = p_dealer_id and pid = v_pid for update;
    if not found or v_ds.qty < v_qty then
      raise exception 'LEDGER: dillerda yetarli qoldiq yo''q (pid=%, bor: %, so''ralgan: %)', v_pid, coalesce(v_ds.qty, 0), v_qty using errcode = 'P0001';
    end if;
    update public.dealer_stock set qty = qty - v_qty, updated_at = now() where id = v_ds.id returning * into v_ds;
    v_line := v_qty * v_price;
    insert into public.dealer_sales (dealer_id, pid, sku, name, qty, sell_usd, total_usd, sale_date)
    values (p_dealer_id, v_pid, coalesce(v_ds.sku, left(e->>'sku', 80)), coalesce(v_ds.name, left(e->>'name', 300)), v_qty, v_price, round(v_line, 2), current_date);
    select public._fw_num(p->>'pointPct') into v_ppct from jsonb_array_elements(coalesce(v_main->'products', '[]'::jsonb)) p
     where p->>'id' = v_pid::text limit 1;
    if coalesce(v_ppct, 0) > 0 and v_usd_val > 0 then
      v_points := v_points + round(((v_line * v_ppct / 100) / v_usd_val) / v_step) * v_step;
    end if;
    v_total := v_total + v_line;
    v_profit := v_profit + (v_price - v_ds.avg_cost_usd) * v_qty;
    v_items := v_items || jsonb_build_object('pid', v_pid, 'qty', v_qty, 'priceUsd', v_price, 'costUsd', v_ds.avg_cost_usd, 'dealerQty', v_ds.qty);
  end loop;
  v_owed := round(v_total - v_total * p_pct / 100, 4);
  update public.dealers set debt_usd = round(debt_usd + v_owed, 4), total_sold_usd = round(total_sold_usd + v_owed, 4), points = points + v_points
   where id = p_dealer_id returning * into d;
  return public._ledger_op_finish(p_filial, p_op_key, 'dealer_sale',
    jsonb_build_object('ok', true, 'kind', 'dealer_sale', 'items', v_items, 'saleTotalUsd', round(v_total, 4), 'commissionPct', p_pct,
                       'owedUsd', v_owed, 'profitUsd', round(v_profit - v_total * p_pct / 100, 4), 'points', v_points, 'dealer', public._dealer_json(d)),
    '{}', '{}', '{}', p_staff_id, p_staff_name);
end;
$$;

-- Server funksiyasi uchun belgi: 35 qo'llanganmi (eski mutlaq qiymat yozish yo'llari shunda yopiladi)
create or replace function public.dealer_atomic_available()
 returns boolean
 language sql
 stable
 set search_path = ''
as $$ select true $$;

-- ── 7. Xavfsizlik: eski funksiyalarga qat'iy search_path (Supabase advisor 0011 — function_search_path_mutable) ──
-- Funksiya tanalarida jadval nomlari sxemasiz yozilgan, shuning uchun '' emas — `public, pg_temp`
-- (pg_temp oxirida — vaqtinchalik sxema orqali nom almashtirib bo'lmaydi). Funksiya bo'lmasa — o'tkazib yuboriladi.
do $$
declare f text;
begin
  foreach f in array array[
    'public.login_check_lock(text)', 'public.login_record_failure(text)', 'public.login_record_success(text)',
    'public.dealer_sale_atomic(bigint,jsonb,date)', 'public.sale_checkout_atomic(text,jsonb,numeric,numeric,bigint,bigint,numeric,text)',
    'public.partner_archive_atomic(bigint)', 'public.partner_ledger_add_atomic(bigint,text,numeric,text,text,text,text)',
    'public.partner_upsert_atomic(bigint,text,boolean,numeric,text,text,numeric,text,numeric)',
    'public.partner_monthly_calc_atomic(text,date,date,numeric,numeric)', 'public.partner_undo_period_atomic(text,boolean)'] loop
    if to_regprocedure(f) is not null then
      execute format('alter function %s set search_path = public, pg_temp', f);
    end if;
  end loop;
end $$;

-- ── 6. Huquqlar: faqat server (service_role) ───────────────────────────
revoke all on function public._dealer_json(public.dealers) from public, anon, authenticated;
revoke all on function public._ledger_op_batch_ids(text, text) from public, anon, authenticated;
revoke all on function public._dealer_lock(text, bigint) from public, anon, authenticated;
revoke all on function public.dealer_ship_atomic(text, text, bigint, jsonb, bigint, bigint, text) from public, anon, authenticated;
revoke all on function public.dealer_return_atomic(text, text, bigint, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function public.dealer_sale_record_atomic(text, text, bigint, jsonb, numeric, bigint, text) from public, anon, authenticated;
revoke all on function public.dealer_atomic_available() from public, anon, authenticated;
grant execute on function public.dealer_ship_atomic(text, text, bigint, jsonb, bigint, bigint, text) to service_role;
grant execute on function public.dealer_return_atomic(text, text, bigint, jsonb, bigint, text) to service_role;
grant execute on function public.dealer_sale_record_atomic(text, text, bigint, jsonb, numeric, bigint, text) to service_role;
grant execute on function public.dealer_atomic_available() to service_role;


-- ────────────────────────────────────────────────────────────────────
-- 36-migratsiya (supabase-migration-36-filial-otkazma.sql) — filiallar o'tkazmasi
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════
-- 36-MIGRATSIYA (v24.6) — FILIALLAR O'TKAZMASI: so'rov → jo'natish → yo'lda → sanab qabul
-- ════════════════════════════════════════════════════════════════════════════
-- Egasi qarorlari (2026-10-15):
--   • Jo'natilgan tovar qabul qiluvchi filial omboriga — U SANAB QABUL QILGANDA tushadi (yo'lda: «transit»).
--   • Yo'nalishlar: Baza → filial (so'rov va yuborish), filial → filial, filial → Baza (qaytarish).
--   • So'rovni qisman bajarish mumkin — qolgani ochiq qoladi (yoki «Qolganini yopish»).
--   • Baza foydasi — FILIAL SOTGANDA (jo'natilganda «ichki savdo» YOZILMAYDI). Filialning Bazaga qarzi
--     avvalgidek sotilganda oshadi (_stock_fifo_out → _branch_debt_add, o'zgarmagan).
--   • Kam kelgan tovar: qabul qiluvchi izoh yozadi (majburiy), farq jo'natuvchiga boradi — u «omborga qaytdi»
--     yoki «yo'qotish» deb hal qiladi.
-- Faqat QO'SHADI (yangi jadvallar, ustun, funksiyalar; CHECK ro'yxatlari kengaytiriladi). Takror ishga
-- tushirish xavfsiz. 27 va 35 dan KEYIN. Faqat server (service_role) — brauzer rollariga huquq yo'q.
-- Eski yo'l (stock-debt-ops stock_out/transfer — «ichki savdo» bilan) saqlanadi: yangilanmagan sahifa ishlayveradi.

do $$ begin
  if to_regprocedure('public._stock_fifo_out(text,bigint,numeric,text,text,text,text,text,text,bigint,text)') is null
     or to_regprocedure('public._ledger_op_batch_ids(text,text)') is null then
    raise exception '36-migratsiya: avval 27 va 35-migratsiyalar qo''llanishi kerak';
  end if;
end $$;

-- ── 1. Partiya: Baza tannarxi (Bazadan kelgan tovarda — Baza foydasini filial sotganda hisoblash uchun) ──
alter table public.batches add column if not exists base_cost_usd numeric;

-- ── 2. O'tkazma hujjati (OT-0001) va jo'natmalari ───────────────────────────
create sequence if not exists public.branch_transfer_no_seq;
create table if not exists public.branch_transfers (
  id bigint generated always as identity primary key,
  no text not null unique,
  kind text not null,                       -- request | send | return
  from_filial text not null,                -- jo'natuvchi (tovar egasi)
  to_filial text not null,                  -- qabul qiluvchi
  status text not null default 'open',      -- open | done (hammasi jo'natildi) | closed (qolgani yopildi)
  items jsonb not null default '[]'::jsonb, -- [{pid, sku, name, qty (so'ralgan), shipped}]
  note text, priority text, need_by date,
  created_by text, created_by_id bigint, created_at timestamptz not null default now(),
  closed_at timestamptz, closed_by text, close_note text,
  constraint branch_transfers_kind_chk check (kind in ('request','send','return')),
  constraint branch_transfers_status_chk check (status in ('open','done','closed')),
  constraint branch_transfers_dir_chk check (from_filial <> to_filial and from_filial ~ '^[a-z0-9_]{1,40}$' and to_filial ~ '^[a-z0-9_]{1,40}$')
);
create index if not exists branch_transfers_from_idx on public.branch_transfers (from_filial, created_at desc);
create index if not exists branch_transfers_to_idx on public.branch_transfers (to_filial, created_at desc);

create table if not exists public.branch_transfer_shipments (
  id bigint generated always as identity primary key,
  transfer_id bigint not null references public.branch_transfers(id),
  seq integer not null,
  status text not null default 'transit',   -- transit | received | diff (kam keldi, jo'natuvchi hal qiladi) | resolved
  lines jsonb not null default '[]'::jsonb, -- [{pid, qty, localId, batchId, srcBatchId, srcLocalId, srcCost, cost, recv}]
  received jsonb,                           -- [{pid, qty}]
  recv_note text, resolution text, loss_usd numeric,
  shipped_by text, shipped_at timestamptz not null default now(),
  received_by text, received_at timestamptz,
  resolved_by text, resolved_at timestamptz,
  constraint branch_transfer_shipments_status_chk check (status in ('transit','received','diff','resolved')),
  constraint branch_transfer_shipments_res_chk check (resolution is null or resolution in ('returned','loss')),
  unique (transfer_id, seq)
);
alter table public.branch_transfers enable row level security;
alter table public.branch_transfer_shipments enable row level security;
revoke all on public.branch_transfers, public.branch_transfer_shipments from public, anon, authenticated;
revoke all on sequence public.branch_transfer_no_seq from public, anon, authenticated;

-- ── 3. Jurnal turlari (avvalgilari saqlanadi) ───────────────────────────────
alter table public.stock_ledger drop constraint if exists stock_ledger_kind_chk;
alter table public.stock_ledger add constraint stock_ledger_kind_chk check (op_kind in ('opening','archive','sale','sale_edit','sale_void','sale_return','kirim','import',
  'opening_stock','edit','delete','arrive','revision','transfer_out','transfer_in','dealer_out','dealer_return',
  'writeoff','writeoff_cancel','b2b_out','b2b_in','b2b_restock','transfer_back','transfer_short'));
alter table public.ledger_ops drop constraint if exists ledger_ops_kind_chk;
alter table public.ledger_ops add constraint ledger_ops_kind_chk check (kind in ('sale','sale_return','sale_void','sale_edit','cust_set','supp_set',
  'batches_create','batch_edit','batch_delete','batch_arrive','revision','stock_out','firma_supp_pay',
  'writeoff','writeoff_cancel','b2b_ship','b2b_receive','b2b_ack','b2b_restock','supp_advance','supp_advance_apply',
  'dealer_ship','dealer_return','dealer_sale','tr_request','tr_ship','tr_receive','tr_resolve','tr_close'));

-- ── 3b. Javobdagi partiyalar: pid/bno/kelib chiqishi ham (brauzer yangi «tr…» partiyani ro'yxatga qo'shishi uchun).
-- Faqat KALIT QO'SHILDI — avvalgi kalitlar o'zgarmagan (eski sahifalar ularni e'tiborsiz qoldiradi).
create or replace function public._fw_authority(p_filial text, p_cust bigint[], p_supp bigint[], p_batches bigint[])
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object(
    'filial', p_filial,
    'customers', coalesce((select jsonb_object_agg(customer_local_id::text, debt) from public.customer_balances
                            where filial = p_filial and customer_local_id = any(coalesce(p_cust, '{}'))), '{}'::jsonb),
    'suppliers', coalesce((select jsonb_object_agg(supplier_local_id::text, jsonb_build_object('debt', debt, 'paid', total_paid)) from public.supplier_balances
                            where filial = p_filial and supplier_local_id = any(coalesce(p_supp, '{}'))), '{}'::jsonb),
    'batches', coalesce((select jsonb_agg(jsonb_build_object('filial', filial, 'localId', local_id, 'qty', qty, 'sold', sold, 'status', status, 'costUsd', cost_usd,
                            'pid', pid, 'bno', bno, 'origin', origin, 'fromBranch', from_branch, 'date', batch_date) order by id)
                          from public.batches where id = any(coalesce(p_batches, '{}'))), '[]'::jsonb),
    'branchDebt', coalesce((select data->'branchDebt' from public.app_data where id = 'main'), '{}'::jsonb));
$$;
revoke all on function public._fw_authority(text, bigint[], bigint[], bigint[]) from public, anon, authenticated;

-- ── 4. Hujjat → brauzer formati ─────────────────────────────────────────────
create or replace function public._tr_json(t public.branch_transfers)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select jsonb_build_object('id', t.id, 'no', t.no, 'kind', t.kind, 'from', t.from_filial, 'to', t.to_filial, 'status', t.status,
    'items', t.items, 'note', t.note, 'priority', t.priority, 'needBy', t.need_by, 'createdBy', t.created_by, 'createdAt', t.created_at,
    'closedAt', t.closed_at, 'closedBy', t.closed_by, 'closeNote', t.close_note,
    'shipments', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'seq', s.seq, 'status', s.status, 'lines', s.lines,
        'received', s.received, 'recvNote', s.recv_note, 'resolution', s.resolution, 'lossUsd', s.loss_usd,
        'shippedBy', s.shipped_by, 'shippedAt', s.shipped_at, 'receivedBy', s.received_by, 'receivedAt', s.received_at,
        'resolvedBy', s.resolved_by, 'resolvedAt', s.resolved_at) order by s.seq)
      from public.branch_transfer_shipments s where s.transfer_id = t.id), '[]'::jsonb));
$$;

-- Ro'yxat: shu filial ishtirok etgan barcha ochiq hujjatlar + oxirgi 100 ta (admin p_all — hammasi)
create or replace function public.branch_transfer_list(p_filial text, p_all boolean default false)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  with mine as (
    select t.* from public.branch_transfers t
     where (p_all or t.from_filial = p_filial or t.to_filial = p_filial)
  ), pick as (
    select * from mine where status = 'open'
       or exists (select 1 from public.branch_transfer_shipments s where s.transfer_id = mine.id and s.status in ('transit','diff'))
    union
    select * from (select * from mine order by created_at desc limit 100) r
  )
  select coalesce(jsonb_agg(public._tr_json(p) order by p.created_at desc), '[]'::jsonb) from pick p;
$$;

-- ── 5. Asosiy amal: so'rov / jo'natish / qabul / farq yechimi / yopish ───────
-- p_filial — amalni bajaruvchi filial (server: xodimning filiali; admin — tanlangan filial).
create or replace function public.branch_transfer_op(p_filial text, p_op_key text, p_kind text, p_payload jsonb,
  p_staff_id bigint default null, p_staff_name text default null, p_is_admin boolean default false)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  p jsonb := coalesce(p_payload, '{}'::jsonb);
  v_res jsonb;
  t public.branch_transfers;
  s public.branch_transfer_shipments;
  r record;
  e jsonb;
  ln jsonb;
  v_items jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_new_lines jsonb := '[]'::jsonb;
  v_to text;
  v_rem numeric;
  v_fifo jsonb;
  v_alloc jsonb;
  src public.batches;
  v_cost numeric;
  v_base numeric;
  v_fromb text;
  v_b public.batches;
  v_n integer := 0;
  v_seq integer;
  v_sid bigint;
  v_side jsonb := '[]'::jsonb;
  v_supps bigint[] := '{}';
  v_bids bigint[] := '{}';
  v_short numeric;
  v_acc numeric;
  v_left numeric;
  v_tot_short numeric := 0;
  v_loss numeric := 0;
  v_name text := left(coalesce(nullif(p_staff_name, ''), 'Admin'), 200);
  v_label text;
  v_note text;
begin
  if p_kind is null or p_kind not in ('tr_request','tr_ship','tr_receive','tr_resolve','tr_close') then
    raise exception 'LEDGER: noma''lum o''tkazma amali' using errcode = 'P0001';
  end if;
  if coalesce(p_filial, '') !~ '^[a-z0-9_]{1,40}$' then raise exception 'LEDGER: filial noto''g''ri' using errcode = 'P0001'; end if;
  v_res := public._ledger_op_replay(p_filial, p_op_key, p_kind);
  if v_res is not null then return v_res; end if;

  -- ── So'rov: qabul qiluvchi (p_filial) jo'natuvchidan (p.from) tovar so'raydi ──
  if p_kind = 'tr_request' then
    v_to := p->>'from';
    if coalesce(v_to, '') !~ '^[a-z0-9_]{1,40}$' or v_to = p_filial then
      raise exception 'LEDGER: qayerdan so''ralishi noto''g''ri' using errcode = 'P0001';
    end if;
    if jsonb_typeof(p->'items') is distinct from 'array' or jsonb_array_length(p->'items') < 1 or jsonb_array_length(p->'items') > 300 then
      raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('pid', x.pid, 'sku', x.sku, 'name', x.name, 'qty', x.qty, 'shipped', 0) order by x.o), '[]'::jsonb)
      into v_items
      from (select public._fw_num(i->>'pid')::bigint as pid, max(left(i->>'sku', 80)) as sku, max(left(i->>'name', 300)) as name,
                   sum(public._fw_num(i->>'qty')) as qty, min(o) as o
              from jsonb_array_elements(p->'items') with ordinality as a(i, o) group by 1) x;
    if exists (select 1 from jsonb_array_elements(v_items) i
                where public._fw_num(i->>'pid') <= 0 or public._fw_num(i->>'qty') <= 0 or public._fw_num(i->>'qty') > 10000000) then
      raise exception 'LEDGER: mahsulot yoki miqdor noto''g''ri' using errcode = 'P0001';
    end if;
    insert into public.branch_transfers (no, kind, from_filial, to_filial, items, note, priority, need_by, created_by, created_by_id)
    values ('OT-' || lpad(nextval('public.branch_transfer_no_seq')::text, 4, '0'), 'request', v_to, p_filial, v_items,
            left(p->>'note', 500), case when p->>'priority' = 'urgent' then 'urgent' else 'normal' end,
            case when coalesce(p->>'needBy', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then (p->>'needBy')::date end, v_name, p_staff_id)
    returning * into t;
    return public._ledger_op_finish(p_filial, p_op_key, p_kind, jsonb_build_object('transfer', public._tr_json(t)),
                                    null, null, null, p_staff_id, p_staff_name);
  end if;

  -- ── Jo'natish: jo'natuvchi (p_filial) — so'rov bo'yicha (qisman ham) yoki to'g'ridan-to'g'ri (p.to) ──
  -- Tovar jo'natuvchidan FIFO bo'yicha chiqadi; qabul qiluvchida «yo'lda» (transit) partiya — omborga sanab qabul qilinganda tushadi.
  if p_kind = 'tr_ship' then
    if jsonb_typeof(p->'items') is distinct from 'array' or jsonb_array_length(p->'items') < 1 or jsonb_array_length(p->'items') > 300 then
      raise exception 'LEDGER: mahsulotlar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    if coalesce(p->>'transferId', '') ~ '^[0-9]{1,18}$' then
      select * into t from public.branch_transfers where id = (p->>'transferId')::bigint for update;
      if not found then raise exception 'LEDGER: o''tkazma topilmadi' using errcode = 'P0001'; end if;
      if t.from_filial <> p_filial then raise exception 'LEDGER: bu so''rov sizga yuborilmagan' using errcode = 'P0001'; end if;
      if t.status <> 'open' then raise exception 'LEDGER: o''tkazma yopilgan' using errcode = 'P0001'; end if;
    else
      v_to := p->>'to';
      if coalesce(v_to, '') !~ '^[a-z0-9_]{1,40}$' or v_to = p_filial then
        raise exception 'LEDGER: qabul qiluvchi filial noto''g''ri' using errcode = 'P0001';
      end if;
      select coalesce(jsonb_agg(jsonb_build_object('pid', x.pid, 'sku', x.sku, 'name', x.name, 'qty', x.qty, 'shipped', 0) order by x.o), '[]'::jsonb)
        into v_items
        from (select public._fw_num(i->>'pid')::bigint as pid, max(left(i->>'sku', 80)) as sku, max(left(i->>'name', 300)) as name,
                     sum(public._fw_num(i->>'qty')) as qty, min(o) as o
                from jsonb_array_elements(p->'items') with ordinality as a(i, o) group by 1) x;
      insert into public.branch_transfers (no, kind, from_filial, to_filial, items, note, created_by, created_by_id)
      values ('OT-' || lpad(nextval('public.branch_transfer_no_seq')::text, 4, '0'), case when v_to = 'baza' then 'return' else 'send' end,
              p_filial, v_to, v_items, left(p->>'note', 500), v_name, p_staff_id)
      returning * into t;
    end if;
    v_to := t.to_filial;
    select coalesce(max(seq), 0) + 1 into v_seq from public.branch_transfer_shipments where transfer_id = t.id;
    insert into public.branch_transfer_shipments (transfer_id, seq, status, shipped_by) values (t.id, v_seq, 'transit', v_name)
      returning id into v_sid;
    v_label := t.no || ' (' || v_seq || '-jo''natma)';
    for r in
      select public._fw_num(i->>'pid')::bigint as pid, sum(public._fw_num(i->>'qty')) as qty, max(public._fw_num(i->>'priceUsd')) as price,
             bool_or(i ? 'priceUsd') as has_price
        from jsonb_array_elements(p->'items') i group by 1 order by 1
    loop
      if r.pid is null or r.pid <= 0 or r.qty is null or r.qty <= 0 or r.qty > 10000000 then
        raise exception 'LEDGER: mahsulot yoki miqdor noto''g''ri' using errcode = 'P0001';
      end if;
      select i into e from jsonb_array_elements(t.items) i where public._fw_num(i->>'pid') = r.pid limit 1;
      if e is null then raise exception 'LEDGER: bu mahsulot o''tkazmada yo''q (pid=%)', r.pid using errcode = 'P0001'; end if;
      v_rem := public._fw_num(e->>'qty') - public._fw_num(e->>'shipped');
      if r.qty > v_rem + 0.000001 then
        raise exception 'LEDGER: so''ralganidan ko''p jo''natib bo''lmaydi (pid=%, qolgan %)', r.pid, v_rem using errcode = 'P0001';
      end if;
      if p_filial = 'baza' and (not r.has_price or r.price < 0 or r.price > 10000000) then
        raise exception 'LEDGER: filial narxi noto''g''ri (pid=%)', r.pid using errcode = 'P0001';
      end if;
      v_fifo := public._stock_fifo_out(p_filial, r.pid, r.qty, 'transfer_out', p_op_key || ':o:' || r.pid, p_op_key, 'transfer', t.no,
                                       v_label, p_staff_id, p_staff_name);
      -- konsignatsiya tovari jo'natuvchidan chiqdi — ta'minotchi qarzi jo'natuvchida. Filial qarzi YO'Q (bu sotuv emas).
      v_side := v_side || coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(v_fifo->'side', '[]'::jsonb)) x
                                     where x->>'kind' = 'consignment'), '[]'::jsonb);
      for v_alloc in select * from jsonb_array_elements(v_fifo->'allocs') loop
        select * into src from public.batches where id = (v_alloc->>'batchId')::bigint;
        v_bids := v_bids || src.id;
        if p_filial = 'baza' then
          -- Baza → filial: filial narxi (diller narxi) — filial qarzi sotilganda shu narxda; Baza tannarxi saqlanadi
          v_cost := r.price; v_base := public._fw_num(v_alloc->>'cost'); v_fromb := 'baza';
        elsif v_to = 'baza' then
          -- filial → Baza (qaytarish): Bazadan kelgan tovar — Baza tannarxida qaytadi
          v_cost := case when src.from_branch = 'baza' and src.base_cost_usd is not null then src.base_cost_usd
                         else public._fw_num(v_alloc->>'cost') end;
          v_base := null; v_fromb := null;
        else
          -- filial → filial: o'sha narx; Bazadan kelgan bo'lsa — qarz baribir Bazaga (sotilganda)
          v_cost := public._fw_num(v_alloc->>'cost'); v_base := src.base_cost_usd; v_fromb := src.from_branch;
        end if;
        v_n := v_n + 1;
        v_b := public._batch_insert(v_to, 'tr' || v_sid || '-' || v_n, r.pid, public._fw_num(v_alloc->>'take'), round(v_cost, 4), 'transit',
                 jsonb_build_object('bno', t.no, 'origin', 'Oʻtkazma ' || t.no || ': ' || p_filial || ' → ' || v_to,
                   'fromBranch', v_fromb, 'date', to_char(current_date, 'YYYY-MM-DD'), 'performedBy', v_name),
                 'transfer_in', p_op_key || ':i:' || v_n, p_op_key, 'transfer', t.no, p_staff_id, p_staff_name);
        if v_base is not null then update public.batches set base_cost_usd = round(v_base, 4) where id = v_b.id; end if;
        v_bids := v_bids || v_b.id;
        v_lines := v_lines || jsonb_build_object('pid', r.pid, 'qty', v_b.qty, 'localId', v_b.local_id, 'batchId', v_b.id,
          'srcBatchId', src.id, 'srcLocalId', src.local_id, 'srcCost', public._fw_num(v_alloc->>'cost'), 'cost', v_b.cost_usd);
      end loop;
      -- hujjatda jo'natilgan miqdor
      select coalesce(jsonb_agg(case when public._fw_num(i->>'pid') = r.pid
                                     then jsonb_set(i, '{shipped}', to_jsonb(public._fw_num(i->>'shipped') + r.qty)) else i end order by o), '[]'::jsonb)
        into t.items from jsonb_array_elements(t.items) with ordinality as a(i, o);
    end loop;
    v_supps := public._fw_apply_side_debts(p_filial, v_side, 0, p_op_key || ':side', p_op_key, 'transfer', t.no, p_staff_id, p_staff_name);
    update public.branch_transfer_shipments set lines = v_lines where id = v_sid;
    update public.branch_transfers
       set items = t.items,
           status = case when not exists (select 1 from jsonb_array_elements(t.items) i
                                            where public._fw_num(i->>'shipped') < public._fw_num(i->>'qty') - 0.000001) then 'done' else 'open' end
     where id = t.id returning * into t;
    return public._ledger_op_finish(p_filial, p_op_key, p_kind, jsonb_build_object('transfer', public._tr_json(t), 'shipmentId', v_sid),
                                    null, v_supps, v_bids, p_staff_id, p_staff_name);
  end if;

  -- ── Sanab qabul: qabul qiluvchi (p_filial) haqiqatda kelgan sonni kiritadi — omborga aynan shu son tushadi ──
  if p_kind = 'tr_receive' then
    select * into s from public.branch_transfer_shipments where id = public._fw_num(p->>'shipmentId')::bigint for update;
    if not found then raise exception 'LEDGER: jo''natma topilmadi' using errcode = 'P0001'; end if;
    select * into t from public.branch_transfers where id = s.transfer_id for update;
    if t.to_filial <> p_filial then raise exception 'LEDGER: bu jo''natma sizga emas' using errcode = 'P0001'; end if;
    if s.status <> 'transit' then raise exception 'LEDGER: jo''natma allaqachon qabul qilingan' using errcode = 'P0001'; end if;
    if jsonb_typeof(p->'items') is distinct from 'array' then raise exception 'LEDGER: qabul ro''yxati noto''g''ri' using errcode = 'P0001'; end if;
    v_note := nullif(btrim(left(p->>'note', 500)), '');
    for r in select public._fw_num(l->>'pid')::bigint as pid, sum(public._fw_num(l->>'qty')) as shipped
               from jsonb_array_elements(s.lines) l group by 1 order by 1 loop
      select i into e from jsonb_array_elements(p->'items') i where public._fw_num(i->>'pid') = r.pid limit 1;
      if e is null or not (e ? 'qty') then
        raise exception 'LEDGER: har bir mahsulot uchun kelgan sonni kiriting (pid=%)', r.pid using errcode = 'P0001';
      end if;
      v_left := public._fw_num(e->>'qty');
      if v_left < 0 or v_left > r.shipped + 0.000001 then
        raise exception 'LEDGER: kelgan son jo''natilganidan ko''p yoki manfiy (pid=%)', r.pid using errcode = 'P0001';
      end if;
      for ln in select l from jsonb_array_elements(s.lines) with ordinality as a(l, o) where public._fw_num(l->>'pid') = r.pid order by o loop
        v_acc := least(public._fw_num(ln->>'qty'), v_left);
        v_left := v_left - v_acc;
        v_short := public._fw_num(ln->>'qty') - v_acc;
        v_tot_short := v_tot_short + v_short;
        v_n := v_n + 1;
        perform public._stock_move((ln->>'batchId')::bigint, -v_short, 0, case when v_acc > 0 then 'arrive' else 'transfer_short' end,
                  p_op_key || ':r:' || v_n, p_op_key, 'transfer', t.no, coalesce(v_note, t.no), p_staff_id, p_staff_name,
                  case when v_acc > 0 then 'active' else 'deleted' end);
        v_bids := v_bids || (ln->>'batchId')::bigint;
        v_new_lines := v_new_lines || (ln || jsonb_build_object('recv', v_acc));
      end loop;
    end loop;
    if v_tot_short > 0.000001 and coalesce(length(v_note), 0) < 2 then
      raise exception 'LEDGER: kam kelgan bo''lsa — sababini izohda yozing' using errcode = 'P0001';
    end if;
    update public.branch_transfer_shipments
       set lines = v_new_lines, received = p->'items', recv_note = v_note, received_by = v_name, received_at = now(),
           status = case when v_tot_short > 0.000001 then 'diff' else 'received' end
     where id = s.id;
    return public._ledger_op_finish(p_filial, p_op_key, p_kind, jsonb_build_object('transfer', public._tr_json(t), 'shortUnits', v_tot_short),
                                    null, null, v_bids, p_staff_id, p_staff_name);
  end if;

  -- ── Farq yechimi: jo'natuvchi (p_filial) — kam kelgan qism «omborga qaytdi» yoki «yo'qotish» ──
  if p_kind = 'tr_resolve' then
    select * into s from public.branch_transfer_shipments where id = public._fw_num(p->>'shipmentId')::bigint for update;
    if not found then raise exception 'LEDGER: jo''natma topilmadi' using errcode = 'P0001'; end if;
    select * into t from public.branch_transfers where id = s.transfer_id for update;
    if t.from_filial <> p_filial then raise exception 'LEDGER: farqni faqat jo''natuvchi hal qiladi' using errcode = 'P0001'; end if;
    if s.status <> 'diff' then raise exception 'LEDGER: bu jo''natmada hal qilinadigan farq yo''q' using errcode = 'P0001'; end if;
    if coalesce(p->>'resolution', '') not in ('returned','loss') then raise exception 'LEDGER: yechim noto''g''ri' using errcode = 'P0001'; end if;
    for ln in select l from jsonb_array_elements(s.lines) with ordinality as a(l, o) order by o loop
      v_short := public._fw_num(ln->>'qty') - public._fw_num(ln->>'recv');
      continue when v_short <= 0.000001;
      v_n := v_n + 1;
      if p->>'resolution' = 'loss' then
        v_loss := v_loss + v_short * public._fw_num(ln->>'srcCost');
      else
        select * into src from public.batches where id = (ln->>'srcBatchId')::bigint for update;
        if found and src.status <> 'deleted' and src.filial = p_filial and src.sold >= v_short - 0.000001 then
          perform public._stock_move(src.id, 0, -v_short, 'transfer_back', p_op_key || ':b:' || v_n, p_op_key, 'transfer', t.no,
                                     'Oʻtkazmadan qaytdi: ' || t.no, p_staff_id, p_staff_name);
          v_bids := v_bids || src.id;
        else
          v_b := public._batch_insert(p_filial, 'trb' || s.id || '-' || v_n, public._fw_num(ln->>'pid')::bigint, v_short,
                   public._fw_num(ln->>'srcCost'), 'active',
                   jsonb_build_object('bno', t.no, 'origin', 'Oʻtkazmadan qaytdi: ' || t.no, 'fromBranch', src.from_branch,
                     'date', to_char(current_date, 'YYYY-MM-DD'), 'performedBy', v_name),
                   'transfer_back', p_op_key || ':b:' || v_n, p_op_key, 'transfer', t.no, p_staff_id, p_staff_name);
          if src.base_cost_usd is not null then update public.batches set base_cost_usd = src.base_cost_usd where id = v_b.id; end if;
          v_bids := v_bids || v_b.id;
        end if;
      end if;
    end loop;
    update public.branch_transfer_shipments
       set status = 'resolved', resolution = p->>'resolution', loss_usd = round(v_loss, 4), resolved_by = v_name, resolved_at = now()
     where id = s.id;
    return public._ledger_op_finish(p_filial, p_op_key, p_kind, jsonb_build_object('transfer', public._tr_json(t), 'lossUsd', round(v_loss, 4)),
                                    null, null, v_bids, p_staff_id, p_staff_name);
  end if;

  -- ── Qolganini yopish: so'rovning jo'natilmagan qismi bekor (ikki tomon yoki admin) ──
  select * into t from public.branch_transfers where id = public._fw_num(p->>'transferId')::bigint for update;
  if not found then raise exception 'LEDGER: o''tkazma topilmadi' using errcode = 'P0001'; end if;
  if not p_is_admin and p_filial not in (t.from_filial, t.to_filial) then
    raise exception 'LEDGER: bu o''tkazma sizga tegishli emas' using errcode = 'P0001';
  end if;
  if t.status <> 'open' then raise exception 'LEDGER: o''tkazma allaqachon yopilgan' using errcode = 'P0001'; end if;
  update public.branch_transfers set status = 'closed', closed_at = now(), closed_by = v_name, close_note = left(p->>'note', 500)
   where id = t.id returning * into t;
  return public._ledger_op_finish(p_filial, p_op_key, p_kind, jsonb_build_object('transfer', public._tr_json(t)),
                                  null, null, null, p_staff_id, p_staff_name);
end;
$$;

-- ── 6. Baza foydasi — FILIAL SOTGANDA: Bazadan kelgan tovar (base_cost_usd bor) filialda sotilgan/chiqarilgan qismi ──
-- Tushum = filial narxi × son (filial qarzi aynan shu), foyda = (filial narxi − Baza tannarxi) × son. Qaytarish/bekor — ayiriladi.
create or replace function public.branch_income(p_from date, p_to date)
 returns jsonb
 language sql
 stable
 set search_path = ''
as $$
  select coalesce(jsonb_object_agg(x.filial, jsonb_build_object('units', x.units, 'revenueUsd', x.rev, 'profitUsd', x.prof)), '{}'::jsonb)
    from (select b.filial, round(sum(l.d_sold), 4) as units, round(sum(l.d_sold * b.cost_usd), 4) as rev,
                 round(sum(l.d_sold * (b.cost_usd - b.base_cost_usd)), 4) as prof
            from public.stock_ledger l join public.batches b on b.id = l.batch_id
           where b.from_branch = 'baza' and b.filial <> 'baza' and b.base_cost_usd is not null
             and l.op_kind in ('sale','sale_edit','sale_void','sale_return','revision','writeoff','writeoff_cancel','b2b_out')
             and l.created_at >= p_from::timestamptz and l.created_at < (p_to + 1)::timestamptz
           group by b.filial) x;
$$;

-- ── 7. Huquqlar: faqat server (service_role) ───────────────────────────────
revoke all on function public._tr_json(public.branch_transfers) from public, anon, authenticated;
revoke all on function public.branch_transfer_list(text, boolean) from public, anon, authenticated;
revoke all on function public.branch_transfer_op(text, text, text, jsonb, bigint, text, boolean) from public, anon, authenticated;
revoke all on function public.branch_income(date, date) from public, anon, authenticated;
grant execute on function public.branch_transfer_list(text, boolean) to service_role;
grant execute on function public.branch_transfer_op(text, text, text, jsonb, bigint, text, boolean) to service_role;
grant execute on function public.branch_income(date, date) to service_role;
grant select, insert, update on public.branch_transfers, public.branch_transfer_shipments to service_role;
grant usage on sequence public.branch_transfer_no_seq to service_role;


-- ────────────────────────────────────────────────────────────────────
-- 37-migratsiya (supabase-migration-37-maxfiylik-chegirma-versiya.sql) — maxfiylik, chegirma chegarasi, versiya
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════
-- 37-MIGRATSIYA (v24.8) — MAXFIYLIK, CHEGIRMA CHEGARASI, DIRECT SALE, YOZISHDA POYGA
-- ════════════════════════════════════════════════════════════════════════════
-- Egasi qarorlari (2026-10-17):
--   • Tannarx (partiya tannarxi, mahsulot cost/dsCostUsd) — faqat administrator va «tannarx.view»
--     ruxsati bor xodimga. Yangi ruxsat hech bir rolga avtomatik berilmaydi (egasi o'zi beradi).
--   • Chegirma chegarasi: admin bo'lmagan xodim sotuv narxini bazadagi narxdan ko'pi bilan
--     settings.maxDiscountPct (standart 10%) foizga tushira oladi. Asos narx — savdo rejimiga qarab:
--     chakana savdoda chakana narx, optom savdoda optom narx (tannarx × (1 + ustama%)).
--   • Direct Sale: mahsulotga ta'minotchi va narx oldindan belgilanmagan bo'lsa — admin bo'lmasa rad;
--     belgilangan bo'lsa — ta'minotchi va narx faqat mahsulotdagidek (xodim o'zgartira olmaydi).
--   • app_data / app_data_branches — «version» ustuni: har yozuvda +1 (trigger). Server eski versiya
--     bilan yozmoqchi bo'lsa — FW_VERSION_CONFLICT (funksiya 409 qaytaradi, brauzer yangilab qayta urinadi).
--   • record_dealer_sale ning eski 5 va 6 argumentli nusxalari o'chiriladi (23-migratsiyadan beri
--     hech kimga ruxsat yo'q, ilova faqat 7 argumentlisini chaqiradi).
-- Faqat QO'SHADI (ustun, trigger, funksiyalar, ruxsat). Takror ishga tushirish xavfsiz.
-- 34 dan KEYIN (sale_checkout_v34 kerak). Barcha yangi funksiyalar — faqat server (service_role).

do $$ begin
  if to_regprocedure('public.sale_checkout_v34(text,text,jsonb,jsonb,bigint,text,text,boolean,jsonb,numeric)') is null
     or to_regprocedure('public._fw_num(text)') is null then
    raise exception '37-migratsiya: avval 27 va 34-migratsiyalar qo''llanishi kerak';
  end if;
end $$;

-- ── 1. Versiya ustuni va avtomatik oshirish ─────────────────────────────────
alter table public.app_data add column if not exists version bigint not null default 0;
alter table public.app_data_branches add column if not exists version bigint not null default 0;

create or replace function public._fw_bump_version()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  new.version := coalesce(old.version, 0) + 1;
  return new;
end;
$$;

-- app_data: faqat branchDebt o'zgargan yozuv (filial sotuvi — _branch_debt_add) versiyani oshirmaydi —
-- aks holda har sotuvdan keyin admin saqlashi keraksiz 409 olardi (branchDebt'ni server baribir bazadagidek saqlaydi)
create or replace function public._fw_bump_version_main()
 returns trigger
 language plpgsql
 set search_path = ''
as $$
begin
  if (new.data - 'branchDebt') is distinct from (old.data - 'branchDebt') then
    new.version := coalesce(old.version, 0) + 1;
  else
    new.version := coalesce(old.version, 0);
  end if;
  return new;
end;
$$;

create or replace trigger fw_app_data_version before update on public.app_data
  for each row execute function public._fw_bump_version_main();
create or replace trigger fw_app_data_branches_version before update on public.app_data_branches
  for each row execute function public._fw_bump_version();

-- ── 2. Versiya tekshiruvi bilan yozish (bitta tranzaksiyada: asosiy qator + filial qatorlari) ──
-- p_main — null bo'lsa asosiy qator yozilmaydi. p_main_base — server o'qigan versiya (null — tekshirilmaydi).
-- p_keep_branch_debt — true bo'lsa branchDebt bazadagisi qoladi (27 dan keyin filial qarzi — server hisobi).
-- p_branches — [{key, data, base}] (base null — tekshirilmaydi; qator yo'q bo'lsa base 0 yoki null bo'lishi kerak).
-- Natija: {main: <yangi versiya>, branches: {key: <yangi versiya>}}. Ziddiyat — FW_VERSION_CONFLICT|<qator>|<joriy versiya>.
create or replace function public.app_data_save_cas(
  p_main jsonb, p_main_base bigint, p_branches jsonb, p_keep_branch_debt boolean default true)
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_cur bigint;
  v_new bigint;
  v_out jsonb := '{}'::jsonb;
  v_br jsonb := '{}'::jsonb;
  v_e jsonb;
  v_key text;
  v_base bigint;
begin
  if p_main is not null then
    if jsonb_typeof(p_main) <> 'object' then raise exception 'LEDGER: ma''lumot noto''g''ri' using errcode = 'P0001'; end if;
    select version into v_cur from public.app_data where id = 'main' for update;
    if not found then
      if coalesce(p_main_base, 0) <> 0 then
        raise exception 'FW_VERSION_CONFLICT|main|0' using errcode = 'P0001';
      end if;
      insert into public.app_data (id, data, updated_at) values ('main', p_main, now())
        on conflict (id) do nothing;
      if not found then raise exception 'FW_VERSION_CONFLICT|main|-1' using errcode = 'P0001'; end if;
      v_new := 0;
    else
      if p_main_base is not null and v_cur <> p_main_base then
        raise exception 'FW_VERSION_CONFLICT|main|%', v_cur using errcode = 'P0001';
      end if;
      update public.app_data
         set data = case when p_keep_branch_debt
                         then (p_main - 'branchDebt') || jsonb_build_object('branchDebt', coalesce(data->'branchDebt', '{}'::jsonb))
                         else p_main end,
             updated_at = now()
       where id = 'main'
      returning version into v_new;
    end if;
    v_out := v_out || jsonb_build_object('main', v_new);
  end if;

  if p_branches is not null then
    if jsonb_typeof(p_branches) <> 'array' or jsonb_array_length(p_branches) > 50 then
      raise exception 'LEDGER: filiallar ro''yxati noto''g''ri' using errcode = 'P0001';
    end if;
    for v_e in select e from jsonb_array_elements(p_branches) e order by e->>'key' loop
      v_key := v_e->>'key';
      if coalesce(v_key, '') !~ '^[a-z0-9_]{1,40}$' or jsonb_typeof(v_e->'data') <> 'object' then
        raise exception 'LEDGER: filial ma''lumoti noto''g''ri' using errcode = 'P0001';
      end if;
      v_base := case when v_e->>'base' ~ '^[0-9]{1,18}$' then (v_e->>'base')::bigint end;
      select version into v_cur from public.app_data_branches where branch_key = v_key for update;
      if not found then
        if coalesce(v_base, 0) <> 0 then
          raise exception 'FW_VERSION_CONFLICT|%|0', v_key using errcode = 'P0001';
        end if;
        insert into public.app_data_branches (branch_key, data, updated_at) values (v_key, v_e->'data', now())
          on conflict (branch_key) do nothing;
        if not found then raise exception 'FW_VERSION_CONFLICT|%|-1', v_key using errcode = 'P0001'; end if;
        v_new := 0;
      else
        if v_base is not null and v_cur <> v_base then
          raise exception 'FW_VERSION_CONFLICT|%|%', v_key, v_cur using errcode = 'P0001';
        end if;
        update public.app_data_branches set data = v_e->'data', updated_at = now()
         where branch_key = v_key
        returning version into v_new;
      end if;
      v_br := v_br || jsonb_build_object(v_key, v_new);
    end loop;
    v_out := v_out || jsonb_build_object('branches', v_br);
  end if;
  return v_out;
end;
$$;

-- ── 3. «tannarx.view» ruxsati (hech bir rolga avtomatik berilmaydi) ────────
insert into public.permissions (key, module, label) values
  ('tannarx.view', 'ombor', 'Tannarx, partiya narxi va foydani koʻrish')
on conflict (key) do nothing;

-- ── 4a. Son yoki standart qiymat (_fw_num noto'g'ri/yo'q qiymatda 0 qaytaradi — bu yerda standart kerak) ──
create or replace function public._fw_num_or(p text, p_default numeric)
 returns numeric
 language sql
 immutable
 set search_path = ''
as $$
  select case when p ~ '^\s*-?[0-9]{1,18}(\.[0-9]{1,40})?([eE][-+]?[0-9]{1,2})?\s*$' then trim(p)::numeric else p_default end;
$$;

-- ── 4. Savdo: chegirma chegarasi va Direct Sale — sale_checkout_v34 dan OLDIN, o'sha tranzaksiyada ──
-- p_price_mode: 'retail' (chakana) yoki 'wholesale' (optom). Admin (p_role = 'admin') — tekshirilmaydi.
-- Asos narx — ilovadagidek: tannarx = mahsulotda Direct Sale narxi (dsCostUsd > 0) bo'lsa o'sha, aks holda
-- filialdagi eng eski faol partiya tannarxi (FIFO); chakana = round(tannarx × (1 + markupPct/100)),
-- optom = round(tannarx × (1 + optMarkupPct/100), 2). Sotuv narxi (chek chegirmasi bilan) asosdan
-- settings.maxDiscountPct (standart 10) foizdan ko'p past bo'lsa — DISCOUNT_LIMIT.
create or replace function public.sale_checkout_v37(
  p_filial text, p_op_key text, p_sale jsonb, p_box_payments jsonb,
  p_staff_id bigint, p_staff_name text, p_role text, p_loss_ack boolean default false,
  p_overpay jsonb default null, p_credit_use_uzs numeric default 0, p_price_mode text default 'retail')
 returns jsonb
 language plpgsql
 set search_path = ''
as $$
declare
  v_main jsonb;
  v_max numeric;
  v_disc numeric;
  v_mode text := case when p_price_mode = 'wholesale' then 'wholesale' else 'retail' end;
  v_e jsonb;
  v_p jsonb;
  v_pid text;
  v_cost numeric;
  v_pct numeric;
  v_base numeric;
  v_eff numeric;
  v_floor numeric;
begin
  -- Takror so'rov (o'sha kalit) — v34 avvalgi natijani qaytaradi, qayta tekshirilmaydi
  if p_role <> 'admin' and not exists (select 1 from public.ledger_ops where filial = p_filial and op_key = p_op_key) then
    select data into v_main from public.app_data where id = 'main';
    v_max := public._fw_num_or(v_main->'settings'->>'maxDiscountPct', 10);
    if v_max < 0 then v_max := 0; elsif v_max > 100 then v_max := 100; end if;
    v_disc := coalesce(public._fw_num(p_sale->>'discPct'), 0);
    if v_disc < 0 then v_disc := 0; elsif v_disc > 100 then v_disc := 100; end if;
    for v_e in select e from jsonb_array_elements(coalesce(p_sale->'items', '[]'::jsonb)) e loop
      v_pid := v_e->>'pid';
      select p into v_p from jsonb_array_elements(coalesce(v_main->'products', '[]'::jsonb)) p where p->>'id' = v_pid limit 1;
      -- Direct Sale: faqat mahsulotda oldindan belgilangan ta'minotchi va narx bilan
      if coalesce(v_e->>'directSupply', 'false') = 'true' then
        if v_p is null or coalesce(v_p->>'directSale', 'false') <> 'true' or coalesce(v_p->>'dsSuppId', '') = ''
           or coalesce(public._fw_num(v_p->>'dsCostUsd'), 0) <= 0 then
          raise exception 'LEDGER: Direct Sale: mahsulotga ta''minotchi va narx belgilanmagan (pid=%)', v_pid using errcode = 'P0001';
        end if;
        if coalesce(v_e->>'suppId', '') <> v_p->>'dsSuppId'
           or abs(coalesce(public._fw_num(v_e->>'costUsd'), -1) - public._fw_num(v_p->>'dsCostUsd')) > 0.0001 then
          raise exception 'LEDGER: Direct Sale: ta''minotchi yoki narx mahsulotdagidan farq qiladi (pid=%)', v_pid using errcode = 'P0001';
        end if;
      end if;
      -- Chegirma chegarasi
      v_cost := null;
      if v_p is not null and coalesce(v_p->>'directSale', 'false') = 'true' and coalesce(public._fw_num(v_p->>'dsCostUsd'), 0) > 0 then
        v_cost := public._fw_num(v_p->>'dsCostUsd');
      elsif v_pid ~ '^[0-9]{1,18}$' then
        select b.cost_usd into v_cost from public.batches b
         where b.filial = p_filial and b.pid = v_pid::bigint and b.deleted_at is null
           and b.status not in ('transit', 'deleted', 'empty') and b.qty - b.sold > 0
         order by b.batch_date, b.id limit 1;
      end if;
      continue when v_cost is null or v_cost <= 0;
      if v_mode = 'wholesale' then
        v_pct := public._fw_num_or(v_p->>'optMarkupPct', 15);
        v_base := round(v_cost * (1 + v_pct / 100), 2);
      else
        v_pct := public._fw_num_or(v_p->>'markupPct', 25);
        v_base := round(v_cost * (1 + v_pct / 100));
      end if;
      v_eff := coalesce(public._fw_num(v_e->>'sellUsd'), 0) * (1 - v_disc / 100);
      v_floor := v_base * (1 - v_max / 100);
      if v_eff < v_floor - 0.01 then
        raise exception 'LEDGER: DISCOUNT_LIMIT|max=%|pid=%|floor=%', v_max, v_pid, round(v_floor, 2) using errcode = 'P0001';
      end if;
    end loop;
  end if;
  return public.sale_checkout_v34(p_filial, p_op_key, p_sale, p_box_payments, p_staff_id, p_staff_name, p_role,
                                  p_loss_ack, p_overpay, p_credit_use_uzs);
end;
$$;

-- ── 5. record_dealer_sale — eski overloadlar (5 va 6 argument) ──────────────
drop function if exists public.record_dealer_sale(bigint, numeric, numeric, text, text);
drop function if exists public.record_dealer_sale(bigint, numeric, numeric, text, text, numeric);

-- ── 6. Huquqlar (faqat server) ─────────────────────────────────────────────
revoke all on function public._fw_bump_version() from public, anon, authenticated;
revoke all on function public._fw_bump_version_main() from public, anon, authenticated;
revoke all on function public._fw_num_or(text, numeric) from public, anon, authenticated;
revoke all on function public.app_data_save_cas(jsonb, bigint, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.app_data_save_cas(jsonb, bigint, jsonb, boolean) to service_role;
revoke all on function public.sale_checkout_v37(text, text, jsonb, jsonb, bigint, text, text, boolean, jsonb, numeric, text) from public, anon, authenticated;
grant execute on function public.sale_checkout_v37(text, text, jsonb, jsonb, bigint, text, text, boolean, jsonb, numeric, text) to service_role;

comment on column public.app_data.version is '37-migratsiya: har yozuvda +1 (trigger) — eski versiya bilan yozish rad etiladi (409)';
comment on column public.app_data_branches.version is '37-migratsiya: har yozuvda +1 (trigger) — eski versiya bilan yozish rad etiladi (409)';

-- ────────────────────────────────────────────────────────────────────
-- 38-migratsiya (supabase-migration-38-parol-tiklash.sql) — parolni tiklash (Telegram kod), seanslarni yopish
-- ────────────────────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════
-- 38-MIGRATSIYA (v24.9) — PAROLNI TIKLASH (Telegram kod) va SEANSLARNI YOPISH
-- ════════════════════════════════════════════════════════════════════════════
-- Egasi qarori (2026-10-23): «Admin tiklaydi + Telegram kod».
--   • Xodim (egasi ham) o'z Telegramini bir marta ulaydi (botga «Start»). «Parolni unutdingizmi?» →
--     login → botga 6 xonali kod (10 daqiqa, 5 urinish) → yangi parol. Kod bazada faqat xesh ko'rinishida.
--   • Admin xodim parolini tiklasa — vaqtinchalik parol, xodim kirganda yangisini qo'yishga majbur
--     (belgi auth foydalanuvchisining app_metadata'sida — brauzer o'zgartira olmaydi), eski seanslar yopiladi.
-- Faqat QO'SHADI (3 jadval, 1 funksiya). Takror ishga tushirish xavfsiz. Barchasi — faqat server (service_role).

do $$ begin
  if to_regclass('public.staff') is null then
    raise exception '38-migratsiya: avval 5-migratsiya (staff jadvali) qo''llanishi kerak';
  end if;
end $$;

-- ── 1. Xodimning Telegram ulanishi va tiklash kodi ──────────────────────────
create table if not exists public.staff_pw_reset (
  staff_id bigint primary key references public.staff(id) on delete cascade,
  tg_chat_id text,
  tg_name text,
  tg_linked_at timestamptz,
  link_code text,
  link_code_exp timestamptz,
  code_hash text,
  code_exp timestamptz,
  code_attempts integer not null default 0,
  last_sent_at timestamptz,
  sent_count integer not null default 0,
  sent_window timestamptz,
  updated_at timestamptz not null default now(),
  constraint staff_pw_reset_chat_chk check (tg_chat_id is null or tg_chat_id ~ '^-?[0-9]{3,20}$'),
  constraint staff_pw_reset_attempts_chk check (code_attempts between 0 and 100 and sent_count between 0 and 1000)
);
alter table public.staff_pw_reset enable row level security;

-- ── 2. So'rovlar jurnali (IP bo'yicha cheklov — ko'p urinishdan himoya) ──────
create table if not exists public.pw_reset_ip_log (
  id bigint generated always as identity primary key,
  ip text not null,
  at timestamptz not null default now()
);
create index if not exists pw_reset_ip_log_ip_at_idx on public.pw_reset_ip_log (ip, at);
alter table public.pw_reset_ip_log enable row level security;

-- ── 2b. Noto'g'ri parol urinishlari va vaqtinchalik blok (egasi qarori 2026-10-23) ──
-- 5 ta noto'g'ri parol → 15 daqiqa blok; blokdan keyin yana 3 ta noto'g'ri → 30 daqiqa (har safar).
-- To'g'ri kirish, Telegram kod bilan tiklash yoki admin — hisobni tozalaydi. Kalit: 'l:' + login (kichik harf).
create table if not exists public.login_guard (
  login_key text primary key,
  fails integer not null default 0,
  stage integer not null default 0,
  locked_until timestamptz,
  last_fail_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint login_guard_chk check (fails between 0 and 1000 and stage between 0 and 10 and length(login_key) <= 120)
);
alter table public.login_guard enable row level security;

-- ── 3. Foydalanuvchining barcha seanslarini yopish (parol tiklanganda) ──────
-- Auth sxemasi yo'q yoki huquq yetmasa — xato bermaydi (-1): funksiya ishlashda davom etadi,
-- eski kirish tokeni o'z muddati (≈1 soat) tugaguncha amal qiladi.
create or replace function public.fw_revoke_sessions(p_uid uuid)
 returns integer
 language plpgsql
 security definer
 set search_path = ''
as $$
declare
  n integer := 0;
begin
  if p_uid is null then return 0; end if;
  begin
    if to_regclass('auth.sessions') is not null then
      execute 'delete from auth.sessions where user_id = $1' using p_uid;
      get diagnostics n = row_count;
    end if;
    if to_regclass('auth.refresh_tokens') is not null then
      execute 'delete from auth.refresh_tokens where user_id = $1::text' using p_uid;
    end if;
  exception when insufficient_privilege or undefined_column or undefined_table then
    return -1;
  end;
  return n;
end;
$$;

-- ── 4. Huquqlar (faqat server) ─────────────────────────────────────────────
revoke all on table public.staff_pw_reset from public, anon, authenticated;
revoke all on table public.pw_reset_ip_log from public, anon, authenticated;
grant select, insert, update, delete on table public.staff_pw_reset to service_role;
grant select, insert, delete on table public.pw_reset_ip_log to service_role;
revoke all on table public.login_guard from public, anon, authenticated;
grant select, insert, update, delete on table public.login_guard to service_role;
revoke all on function public.fw_revoke_sessions(uuid) from public, anon, authenticated;
grant execute on function public.fw_revoke_sessions(uuid) to service_role;

comment on table public.staff_pw_reset is '38-migratsiya: xodim Telegram ulanishi va parol tiklash kodi (faqat xesh) — faqat server';
comment on table public.login_guard is '38-migratsiya: noto''g''ri parol urinishlari va vaqtinchalik blok (5 → 15 daqiqa, keyin 3 → 30 daqiqa) — faqat server';
comment on table public.pw_reset_ip_log is '38-migratsiya: parol tiklash so''rovlari (IP bo''yicha cheklov) — faqat server';

-- Run once in Supabase > SQL Editor
create table profiles(id uuid primary key references auth.users on delete cascade, name text, email text, dept text,
  role text not null default 'requester' check (role in ('requester','approver','storekeeper','admin')), active boolean not null default false);
create table items(material_no text primary key, description text, uom text, stock numeric default 0, unit_price numeric default 0);
create table codes(id bigserial primary key, section text, kind text, code text, label text);
create table reqs(rs bigserial primary key, user_id uuid references profiles(id), section text, cc text, gl text, remarks text,
  status text not null default 'Submitted', created timestamptz default now(), actor text, decided timestamptz, released timestamptz, closed timestamptz);
create table lines(id bigserial primary key, rs bigint references reqs(rs) on delete cascade, material_no text, description text, uom text, qty numeric, unit_price numeric);

create function new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into profiles(id,name,email,dept) values(new.id,new.raw_user_meta_data->>'name',new.email,new.raw_user_meta_data->>'dept'); return new; end $$;
create trigger on_signup after insert on auth.users for each row execute function new_user();

create function my_role() returns text language sql stable security definer set search_path=public as $$ select role from profiles where id=auth.uid() and active $$;

alter table profiles enable row level security; alter table items enable row level security; alter table codes enable row level security;
alter table reqs enable row level security; alter table lines enable row level security;

create policy p_sel on profiles for select to authenticated using (true);
create policy p_upd on profiles for update to authenticated using (my_role()='admin');
create policy i_sel on items for select to authenticated using (my_role() is not null);
create policy i_all on items for all to authenticated using (my_role() in ('storekeeper','admin')) with check (my_role() in ('storekeeper','admin'));
create policy c_sel on codes for select to authenticated using (my_role() is not null);
create policy c_all on codes for all to authenticated using (my_role()='admin') with check (my_role()='admin');
create policy r_sel on reqs for select to authenticated using (user_id=auth.uid() or my_role() in ('approver','storekeeper','admin'));
create policy r_ins on reqs for insert to authenticated with check (user_id=auth.uid() and my_role() is not null);
create policy r_upd on reqs for update to authenticated using (my_role() in ('approver','admin') or user_id=auth.uid());
create policy l_sel on lines for select to authenticated using (exists(select 1 from reqs r where r.rs=lines.rs));
create policy l_ins on lines for insert to authenticated with check (exists(select 1 from reqs r where r.rs=lines.rs and r.user_id=auth.uid()));

-- Release: checks stock and deducts it in one safe step (storekeeper/admin only)
create function release_req(p_rs bigint) returns void language plpgsql security definer set search_path=public as $$
declare l record;
begin
  if my_role() not in ('storekeeper','admin') then raise exception 'Not allowed'; end if;
  if (select status from reqs where rs=p_rs)<>'Approved' then raise exception 'Request is not approved'; end if;
  for l in select * from lines where rs=p_rs loop
    if (select stock from items where material_no=l.material_no)<l.qty then raise exception 'Not enough stock for %',l.material_no; end if;
  end loop;
  update items i set stock=i.stock-l.qty from lines l where l.rs=p_rs and i.material_no=l.material_no;
  update reqs set status='Released',released=now() where rs=p_rs;
end $$;
insert into codes(section,kind,code,label) values
('Engineering - M&I and E&A','cc','643819001',''),
('Engineering - M&I and E&A','gl','5046000','Operating Supplies'),
('Engineering - M&I and E&A','gl','5034020','PPE'),
('Engineering - IS','cc','643817501','Water'),
('Engineering - IS','cc','643817601','Waste Water Treatment'),
('Engineering - IS','cc','643817101','Steam'),
('Engineering - IS','cc','643817201','Refrigeration'),
('Engineering - IS','cc','643817701','Compressed Air'),
('Engineering - IS','gl','5046000','Operating Supplies'),
('Engineering - IS','gl','5034020','PPE'),
('Engineering - Project','cc','643846001',''),
('Engineering - Project','gl','5046000','Operating Supplies'),
('Engineering - Project','gl','5034020','PPE'),
('Production - Tower 1','cc','643850199','T1 - Process Common'),
('Production - Tower 1','cc','643851199','T1 - F/P Common'),
('Production - Tower 1','gl','5046000','Operating Supplies'),
('Production - Tower 1','gl','5034020','PPE'),
('Production - RTD','cc','643871199','RTD - Process Common'),
('Production - RTD','cc','643871099','RTD - F/P Common'),
('Production - RTD','gl','5046000','Operating Supplies'),
('QA','cc','643821199',''),
('QA','gl','5046000','Operating Supplies'),
('QA','gl','5034020','PPE'),
('QA','gl','5046010','Laboratory Materials'),
('FSC','cc','643816401',''),
('FSC','gl','5046000','Operating Supplies'),
('FSC','gl','5034020','PPE'),
('SHE','cc','643830111',''),
('SHE','gl','6028000','');

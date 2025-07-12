-- Category table
create table Category (
  categoryId uuid primary key default gen_random_uuid(),
  userId uuid references auth.users(id) on delete cascade,
  categoryName text not null,
  categoryEmoji text not null,
  createdAt timestamptz default now(),
  updatedAt timestamptz default now()
);

-- Task table
create table Task (
  taskId uuid primary key default gen_random_uuid(),
  userId uuid references auth.users(id) on delete cascade,
  categoryId uuid references Category(categoryId) on delete set null,
  taskTitle text not null,
  taskContent text not null,
  isCompleted boolean default false,
  dueDate timestamptz,
  createdAt timestamptz default now(),
  updatedAt timestamptz default now(),
  memoId uuid references Memo(memoId) on delete set null,
  shakerId uuid references Shaker(shakerId) on delete set null,
);

-- Shaker table
create table Shaker (
  shakerId uuid primary key default gen_random_uuid(),
  userId uuid references auth.users(id) on delete cascade,
  date timestamptz not null,
  completedTasks uuid[],
  totalTasks int not null,
  createdAt timestamptz default now(),
  updatedAt timestamptz default now()
);

-- Memo table
create table Memo (
  memoId uuid primary key default gen_random_uuid(),
  taskId uuid references Task(taskId) on delete cascade,
  userId uuid references auth.users(id) on delete cascade,
  memoContent text not null,
  createdAt timestamptz default now(),
  updatedAt timestamptz default now()
);

-- MemoTag table (the unique tag pool)
create table MemoTag (
  memoTagId uuid primary key default gen_random_uuid(),
  memoTagContent text not null
);

-- Memo ↔ MemoTag join table
create table Memo_MemoTag (
  memoId uuid references Memo(memoId) on delete cascade,
  memoTagId uuid references MemoTag(memoTagId) on delete cascade,
  primary key (memoId, memoTagId)
);

-- Profile table 
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  avatar_url text,
  created_at timestamp default now()
);
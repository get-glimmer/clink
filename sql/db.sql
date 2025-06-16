-- Category table
create table Category (
  categoryId uuid primary key default gen_random_uuid(),
  userId uuid references auth.users(id) on delete cascade,
  categoryName text not null,
  categoryEmoji text not null,
  createdAt timestamptz default now(),
  updatedAt timestamptz default now()
);

-- Todo table
create table Todo (
  todoId uuid primary key default gen_random_uuid(),
  userId uuid references auth.users(id) on delete cascade,
  categoryId uuid references Category(categoryId) on delete set null,
  todoTitle text not null,
  todoContent text not null,
  isCompleted boolean default false,
  dueDate timestamptz,
  todoEmoji text,
  createdAt timestamptz default now(),
  updatedAt timestamptz default now()
);

-- Memo table
create table Memo (
  memoId uuid primary key default gen_random_uuid(),
  todoId uuid references Todo(todoId) on delete cascade,
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

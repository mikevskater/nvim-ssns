---@module ssns.ui.panels.theme_preview_sql
---Preview SQL that showcases all SSNS highlight groups
---Used by the theme picker to demonstrate syntax highlighting

local M = {}

-- Use [=[ ]=] to avoid conflicts with SQL containing ]]
M.sql = [=[
-- ============================================
-- SSNS Theme Preview
-- This query showcases all highlight groups
-- ============================================

-- Database & Schema References
USE master;
GO

-- Statement Keywords (SELECT, INSERT, CREATE, etc.)
SELECT
    -- Column References
    u.id,
    u.username,
    u.email,
    u.created_at,
    -- Alias References
    o.order_total AS total,
    -- Function Keywords (COUNT, SUM, GETDATE, etc.)
    COUNT(*) AS order_count,
    SUM(o.amount) AS total_amount,
    GETDATE() AS current_date,
    CAST(u.balance AS DECIMAL(10,2)) AS balance,
    COALESCE(u.nickname, 'N/A') AS display_name
-- Clause Keywords (FROM, WHERE, JOIN, etc.)
FROM dbo.Users u
-- Table & View References
INNER JOIN dbo.Orders o ON u.id = o.user_id
LEFT JOIN dbo.UserProfiles up ON u.id = up.user_id
-- Operator Keywords (AND, OR, NOT, IN, BETWEEN)
WHERE u.status = 'active'
    AND o.created_at BETWEEN '2024-01-01' AND '2024-12-31'
    AND u.role IN ('admin', 'user', 'moderator')
    OR NOT u.is_deleted = 1
-- Modifier Keywords (ASC, DESC, NOLOCK, etc.)
ORDER BY u.created_at DESC, u.username ASC;

-- Number Literals
SELECT 42, 3.14159, -100, 0x1F;

-- String Literals
SELECT 'Hello World', N'Unicode String', 'It''s escaped';

-- Parameter References (@params and @@system)
DECLARE @UserId INT = 1;
DECLARE @SearchTerm NVARCHAR(100) = '%test%';
SELECT @@VERSION, @@ROWCOUNT, @@IDENTITY;

-- Procedure & Function Calls
EXEC dbo.GetUserById @UserId = @UserId;
EXEC sp_help 'dbo.Users';

-- Datatype Keywords (INT, VARCHAR, DATETIME, etc.)
CREATE TABLE #TempUsers (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email NVARCHAR(255) UNIQUE,
    balance DECIMAL(18,2) DEFAULT 0.00,
    created_at DATETIME DEFAULT GETDATE(),
    metadata XML NULL
);

-- Constraint Keywords (PRIMARY, KEY, FOREIGN, etc.)
ALTER TABLE dbo.Orders
ADD CONSTRAINT FK_Orders_Users
    FOREIGN KEY (user_id) REFERENCES dbo.Users(id)
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

-- Index Reference
CREATE NONCLUSTERED INDEX IX_Users_Email
ON dbo.Users (email)
INCLUDE (username, created_at);

-- CTE (Common Table Expression)
WITH ActiveUsers AS (
    SELECT id, username, email
    FROM dbo.Users
    WHERE status = 'active'
),
RecentOrders AS (
    SELECT user_id, COUNT(*) as cnt
    FROM dbo.Orders
    WHERE created_at > DATEADD(DAY, -30, GETDATE())
    GROUP BY user_id
)
SELECT * FROM ActiveUsers au
JOIN RecentOrders ro ON au.id = ro.user_id;

-- Unresolved (gray - not in database)
SELECT * FROM dbo.UnknownTable WHERE unknown_col = 1;
]=]

---Get preview SQL as lines
---@return string[]
function M.get_lines()
  return vim.split(M.sql, "\n")
end

return M

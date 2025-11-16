WITH 
--  Convert UTC to South African Time and extract date/time
viewership_sa AS (
    SELECT
        UserID,
        Channel2,
        Duration2,
        -- Convert UTC → South African Time (+2 hours)
        DATEADD(hour, 2, TO_TIMESTAMP(RecordDate2, 'YYYY/MM/DD HH24:MI')) AS RecordDate_SA,
        -- Extract date and time
        TO_DATE(DATEADD(hour, 2, TO_TIMESTAMP(RecordDate2, 'YYYY/MM/DD HH24:MI'))) AS RecordDate_SA_Date,
        TO_CHAR(DATEADD(hour, 2, TO_TIMESTAMP(RecordDate2, 'YYYY/MM/DD HH24:MI')), 'HH24:MI:SS') AS RecordDate_SA_Time
    FROM "BRIGHTTVCASESTUDY"."DATASET"."VIEWSHIP"
),

--  Daily trends
daily_trends AS (
    SELECT
        RecordDate_SA_Date AS View_Date,
        COUNT(DISTINCT UserID) AS Active_Users,
        COUNT(*) AS Total_Sessions,
        SUM(
            DATE_PART('hour', Duration2) * 60 +
            DATE_PART('minute', Duration2) +
            DATE_PART('second', Duration2) / 60.0
        ) AS Total_Minutes_Watched,
        AVG(
            DATE_PART('hour', Duration2) * 60 +
            DATE_PART('minute', Duration2) +
            DATE_PART('second', Duration2) / 60.0
        ) AS Avg_Session_Duration_Minutes
    FROM viewership_sa
    GROUP BY RecordDate_SA_Date
),

--  Hourly viewing pattern
hourly_pattern AS (
    SELECT
        DATE_PART('hour', RecordDate_SA) AS Hour_Of_Day,
        COUNT(*) AS Total_Sessions,
        SUM(
            DATE_PART('hour', Duration2) * 60 +
            DATE_PART('minute', Duration2) +
            DATE_PART('second', Duration2) / 60.0
        ) AS Total_Minutes_Watched
    FROM viewership_sa
    GROUP BY 1
),

--  Demographic viewing patterns
demographic_stats AS (
    SELECT
        CASE 
            WHEN u.Age < 25 THEN 'Under 25'
            WHEN u.Age BETWEEN 25 AND 44 THEN '25–44'
            WHEN u.Age BETWEEN 45 AND 64 THEN '45–64'
            ELSE '65+' 
        END AS Age_Group,
        u.Gender,
        AVG(
            DATE_PART('hour', v.Duration2) * 60 + 
            DATE_PART('minute', v.Duration2) + 
            DATE_PART('second', v.Duration2) / 60.0
        ) AS Avg_Duration_Minutes,
        SUM(
            DATE_PART('hour', v.Duration2) * 60 + 
            DATE_PART('minute', v.Duration2) + 
            DATE_PART('second', v.Duration2) / 60.0
        ) AS Total_Minutes
    FROM "BRIGHTTVCASESTUDY"."DATASET"."USERPROFILE" AS u
    JOIN viewership_sa AS v 
        ON u.UserID = v.UserID
    GROUP BY 1, 2
),

--  Provincial & gender stats
province_stats AS (
    SELECT
        u.Gender,
        u.Age,
        u.Province,
        COUNT(DISTINCT v.UserID) AS Active_Users,
        SUM(
            DATE_PART('hour', v.Duration2) * 60 +
            DATE_PART('minute', v.Duration2) +
            DATE_PART('second', v.Duration2) / 60.0
        ) AS Total_Minutes_Watched,
        AVG(
            DATE_PART('hour', v.Duration2) * 60 +
            DATE_PART('minute', v.Duration2) +
            DATE_PART('second', v.Duration2) / 60.0
        ) AS Avg_Session_Duration_Minutes
    FROM "BRIGHTTVCASESTUDY"."DATASET"."USERPROFILE" AS u
    JOIN viewership_sa AS v 
        ON u.UserID = v.UserID
    GROUP BY u.Gender, u.Age, u.Province
),

--  Channel performance
channel_performance AS (
    SELECT
        v.Channel2 AS Channel,
        COUNT(*) AS Total_Sessions,
        SUM(
            DATE_PART('hour', v.Duration2) * 60 +
            DATE_PART('minute', v.Duration2) +
            DATE_PART('second', v.Duration2) / 60.0
        ) AS Total_Minutes_Watched,
        AVG(
            DATE_PART('hour', v.Duration2) * 60 +
            DATE_PART('minute', v.Duration2) +
            DATE_PART('second', v.Duration2) / 60.0
        ) AS Avg_Session_Duration_Minutes
    FROM viewership_sa AS v
    GROUP BY v.Channel2
),

--  Low-consumption days
low_days AS (
    SELECT
        RecordDate_SA_Date AS Day,
        SUM(
            DATE_PART('hour', Duration2) * 60 +
            DATE_PART('minute', Duration2) +
            DATE_PART('second', Duration2) / 60.0
        ) AS Total_Minutes_Watched
    FROM viewership_sa
    GROUP BY RecordDate_SA_Date
    ORDER BY Total_Minutes_Watched ASC
    LIMIT 3
),

--  Inactive users (no view in 30+ days)
user_last_watch AS (
    SELECT
        UserID,
        MAX(RecordDate_SA_Date) AS Last_Watch_Date
    FROM viewership_sa
    GROUP BY UserID
),
inactive_users AS (
    SELECT
        u.UserID,
        u.Name,
        u.Email,
        u.Province,
        DATEDIFF('day', TO_DATE(ul.Last_Watch_Date), CURRENT_DATE) AS Days_Since_Last_Watch
    FROM user_last_watch ul
    JOIN "BRIGHTTVCASESTUDY"."DATASET"."USERPROFILE" AS u 
        ON u.UserID = ul.UserID
    WHERE ul.Last_Watch_Date < DATEADD(day, -30, CURRENT_DATE)
),

--  User-level viewing with dayname, month, hour, and formatted duration
user_watch AS (
    SELECT
        u.UserID,
        u.Name,
        u.Surname,
        u.Race,
        u.Province,
        u.Gender,
        u.Age,
        CASE 
            WHEN u.Age < 25 THEN 'Under 25'
            WHEN u.Age BETWEEN 25 AND 44 THEN '25 to 44'
            WHEN u.Age BETWEEN 45 AND 64 THEN '45 to 64'
            ELSE '65+'
        END AS Age_Group,
        v.Channel2 AS Channel,
        v.RecordDate_SA_Date AS View_Date,
        TO_CHAR(v.RecordDate_SA_Date, 'MON') AS Month_Name,
        DAYNAME(v.RecordDate_SA_Date) AS Day_Of_Week,
        DATE_PART('hour', v.RecordDate_SA) AS Hour_Of_Day,
        v.RecordDate_SA_Time AS View_Time,
        CASE
            WHEN DATE_PART('hour', v.Duration2) = 0 THEN 
                TO_VARCHAR(DATE_PART('minute', v.Duration2)) || 'm'
            ELSE 
                TO_VARCHAR(DATE_PART('hour', v.Duration2)) || 'h ' || TO_VARCHAR(DATE_PART('minute', v.Duration2)) || 'm'
        END AS Duration_Watched,
        CASE 
            WHEN DATE_PART('hour', v.RecordDate_SA) BETWEEN 5 AND 11 THEN 'Morning '
            WHEN DATE_PART('hour', v.RecordDate_SA) BETWEEN 12 AND 16 THEN 'Afternoon '
            WHEN DATE_PART('hour', v.RecordDate_SA) BETWEEN 17 AND 20 THEN 'Evening '
            ELSE 'Night '
        END AS Time_Bucket
    FROM viewership_sa AS v
    JOIN "BRIGHTTVCASESTUDY"."DATASET"."USERPROFILE" AS u 
        ON u.UserID = v.UserID
),

final_output AS (
    SELECT 
        UserID,
        Surname,
        Gender,
        Channel,
        Age_Group,
        Race,
        Province,
        View_Date,
        Month_Name,
        Day_Of_Week,
        Hour_Of_Day,
        View_Time,
        Time_Bucket,
        Duration_Watched
    FROM user_watch
)


SELECT * 
FROM final_output
ORDER BY View_Date, View_Time; 

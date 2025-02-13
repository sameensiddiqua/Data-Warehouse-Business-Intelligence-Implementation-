--Project 
-- 1. Potential problems when customers book Mindbody’s classes
-- a. How many bookings are added to carts but not purchased? (sales completion rate vs. cart abandonment rate)
SELECT 
    COUNT(*) AS CartAbandonmentCount
FROM 
    FactBookingsAudit
WHERE 
    SalesOrderID IS NULL OR SalesOrderID = 0;

-- b. How long from adding a class to cart to buying it?

SELECT 
    ShoppingCartID,
    MinInCartUntilOrder AS MinutesToPurchase
FROM 
    FactBookingsAudit
WHERE 
    MinInCartUntilOrder IS NOT NULL;


-- c. Which classes show high "transfer" out of or into them?  (Are there patterns by class type or teacher?)
	SELECT 
    c.classTag,
    c.TeacherName,
    COUNT(ba.SalesOrderID) AS TotalBookings,
    SUM(CASE WHEN ba.isRefunded = 1 THEN 1 ELSE 0 END) AS TotalTransfersOut,
    (SUM(CASE WHEN ba.isRefunded = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(ba.SalesOrderID) AS TransferOutRatePercentage
FROM 
    FactBookingsAudit ba
INNER JOIN 
    DimClass c ON ba.ClassID = c.ClassID
GROUP BY 
    c.classTag,
    c.TeacherName
ORDER BY 
    TransferOutRatePercentage DESC;


--2. Recommendations for Mindbody to help customers find what they need
--a. What classes are booked most often? (by class type, time, teacher, daily/weekly/seasonal -- with trends chart)
SELECT 
    c.classTag AS ClassType,
    c.TeacherName,
    COUNT(ba.SalesOrderID) AS TotalBookings
FROM 
    FactBookingsAudit ba
INNER JOIN 
    DimClass c ON ba.ClassID = c.ClassID
GROUP BY 
    c.classTag,
    c.TeacherName
ORDER BY 
    TotalBookings DESC;
	 ---daily 
SELECT 
    d.fulldate AS BookingDate,
    c.classTag AS ClassType,
    COUNT(ba.SalesOrderID) AS TotalBookings
FROM 
    FactBookingsAudit ba
JOIN 
    DimClass c ON ba.ClassID = c.ClassID
JOIN 
    DimDate d ON CAST(c.ClassStartTimeStamp AS DATE) = d.fulldate
GROUP BY 
    d.fulldate,
    c.classTag
ORDER BY 
    BookingDate;


--weekly
SELECT 
    d.calendaryear AS Year,
    d.DayOfWeek AS WeekOfYear,  
    d.englishmonthname AS Month,
    c.classTag AS ClassType,
    COUNT(ba.SalesOrderID) AS WeeklyBookings
FROM 
    FactBookingsAudit ba
INNER JOIN 
    DimClass c ON ba.ClassID = c.ClassID
INNER JOIN 
    DimDate d ON CAST(c.ClassStartTimeStamp AS DATE) = d.fulldate
GROUP BY 
    d.calendaryear,
    d.DayOfWeek,
    d.englishmonthname,
    c.classTag
ORDER BY 
    d.calendaryear ASC, 
    d.DayOfWeek ASC, 
    d.englishmonthname ASC;

--monthly 
SELECT 
    d.calendaryear,
    d.englishmonthname,
    c.classTag AS ClassType,
    COUNT(ba.SalesOrderID) AS MonthlyBookings
FROM 
    FactBookingsAudit ba
INNER JOIN 
    DimClass c ON ba.ClassID = c.ClassID
INNER JOIN 
    DimDate d ON CAST(c.ClassStartTimeStamp AS DATE) = d.fulldate
GROUP BY 
    d.calendaryear,
    d.englishmonthname,
    c.classTag
ORDER BY 
	d.englishmonthname;
    
    
  --Seasonal trends 
SELECT 
    CASE 
        WHEN DATEPART(MONTH, d.fulldate) IN (12, 1, 2) THEN 'Winter'
        WHEN DATEPART(MONTH, d.fulldate) IN (3, 4, 5) THEN 'Spring'
        WHEN DATEPART(MONTH, d.fulldate) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END AS Season,
    c.classTag AS ClassType,
    COUNT(ba.SalesOrderID) AS SeasonalBookings
FROM 
    FactBookingsAudit ba
INNER JOIN 
    DimClass c ON ba.ClassID = c.ClassID
INNER JOIN 
    DimDate d ON CAST(c.ClassStartTimeStamp AS DATE) = d.fulldate
GROUP BY 
    CASE 
        WHEN DATEPART(MONTH, d.fulldate) IN (12, 1, 2) THEN 'Winter'
        WHEN DATEPART(MONTH, d.fulldate) IN (3, 4, 5) THEN 'Spring'
        WHEN DATEPART(MONTH, d.fulldate) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END,
    c.classTag
ORDER BY 
    Season;


	----b. Demographics: what age, gender are buying which classes?
SELECT 
    u.userGender,
    FLOOR(DATEDIFF(DAY, u.userDOB, GETDATE()) / 365.25) AS Age,
    c.ClassID,
    c.ClassTag,
    c.TeacherName
FROM 
    DimUser u
JOIN 
    FactBookingsAudit fba ON u.UserID = fba.UserIDPurchased
JOIN 
    DimClass c ON fba.ClassID = c.ClassID
WHERE 
    fba.isValidClass = 1
    AND fba.isFinished = 1;
--c. Advertising: which channels are bringing in most customers? Are they buying classes?
SELECT 
    u.Advertising,
    COUNT(DISTINCT u.UserID) AS TotalCustomers,
    COUNT(DISTINCT fba.UserIDPurchased) AS CustomersBuyingClasses
FROM 
    DimUser u
LEFT JOIN 
    FactBookingsAudit fba ON u.UserID = fba.UserIDPurchased AND fba.isValidClass = 1
GROUP BY 
    u.Advertising
ORDER BY 
    TotalCustomers DESC;
--d.Coupons and Bundles: how much revenue came from each source?

SELECT 
    SUM(CASE WHEN fba.isBundled = 1 THEN fba.LineTotalCost ELSE 0 END) AS BundledRevenue,
    SUM(CASE WHEN fba.isDiscounted = 1 AND fba.isBundled = 0 THEN fba.LineTotalCost ELSE 0 END) AS CouponRevenue,
    SUM(CASE WHEN fba.isBundled = 0 AND fba.isDiscounted = 0 THEN fba.LineTotalCost ELSE 0 END) AS RegularRevenue,
    SUM(fba.LineTotalCost) AS TotalRevenue
FROM 
    FactBookingsAudit fba
WHERE 
    fba.isValidClass = 1
    AND fba.isFinished = 1;

--e.First time vs repeat customers: how many first time customers buy more classes later?
WITH FirstPurchase AS (
    SELECT 
        UserIDPurchased,
        MIN(OrderDateTime) AS FirstPurchaseDate
    FROM 
        FactBookingsAudit
    WHERE 
        isValidClass = 1
        AND isFinished = 1
    GROUP BY 
        UserIDPurchased
),
RepeatCustomers AS (
    SELECT 
        DISTINCT fba.UserIDPurchased
    FROM 
        FactBookingsAudit fba
    JOIN 
        FirstPurchase fp ON fba.UserIDPurchased = fp.UserIDPurchased
    WHERE 
        fba.OrderDateTime > fp.FirstPurchaseDate
        AND fba.isValidClass = 1
        AND fba.isFinished = 1
)
SELECT 
    COUNT(DISTINCT fp.UserIDPurchased) AS TotalFirstTimeCustomers,
    COUNT(DISTINCT rc.UserIDPurchased) AS TotalRepeatCustomers
FROM 
    FirstPurchase fp
LEFT JOIN 
    RepeatCustomers rc ON fp.UserIDPurchased = rc.UserIDPurchased;













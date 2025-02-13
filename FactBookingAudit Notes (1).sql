/*===ABOUT FactBookingsAudit===========================

-- The grain is INDIVIDUAL shopping cart ClassID additions, linked to orders if they bought it and attendance if they attended
--  It may help to order by ClassID or ShoppingCartID

-- Note: FactAttendanceSummary has some similar values already summed by ClassID
--  If you just want totals about one class, it might already be there

-- Each row is adding one ClassID to cart. Usually 1, but could buy multiple quantity of it on the same row.
-- Each ShoppingCartID can span multiple ClassID rows, such as if they buy multiple ClassIDs in one cart.


===IDs==========================================
ShoppingCartID = the cart that contains this ClassID (and maybe multiple)
  When the cart is purchased, the total paid is for the whole cart

SalesOrderID = unique ID of a Sales Order purchase, also connects Sales to Attendance data
  Tip: check SalesOrderID > 0

UserIDPurchased = the userID who purchased the class. Unregistered users are 9 digits.
UserIDAttended = the userID who attended this class, if any. Could be different user.

==COSTS==========================================
ClassCost = the cost from DimClass for this ClassID, ex: 12.00

CartItemQty = how many of this ClassID are in the cart, ex: 3
  Prof notes say: "If more than 1, they will attend with their friends/spouse"

LineTotalCost = ClassCost x CartItemQty, ex: 12 x 3 = 36.00

===TIME==========================================
CartAddTime = when this ClassID was first added to cart

OrderDateTime = when the Shopping Cart containing this ClassID was purchased (if it was)

ClassStartDateTime = class start datetime from DimClass

MinInCartUntilOrder = minutes from adding ClassID to cart to the cart was ordered. Sometimes quick, sometimes a month.
MinInCartUntilClass = minutes fro adding ClassID to cart before that ClassID started. Negative is buying class LATE.
  Issue: some people added ClassID to cart after class already started. See also isLateCartAdd=1 to see all.

===AUDIT FLAGS =======================================
isValidClass
  = 1 if this ClassID is found in DimClass 
  = 0 if this ClassID NOT found in DimClass
  Issue: some classes were added to cart or bought that don't exist in DimClass

isLateCartAdd
  = 1 if this ClassID was added to cart AFTER class started (from DimClass ClassStartTimeStamp)
  = 0 if ClassID was added BEFORE class started
  Issue: some people added ClassID to cart after class already started. Check MinInCartUntilClass < 0 to see late additions.
   Ex: 82, 55, 33 minutes after class began. Maybe don't want to let them buy classes past a cutoff time to avoid confusion?

isBundled
  = 1 this ClassID was in a cart sale that had a bundle discount applied (5 or more classes purchased, save 10%)
  = 0 no bundle discount applied

isDiscounted
  = 1 this ClassID was in a cart sale that had a coupon holiday discount applied
  = 0 no coupon applied

isCredited = 1 this ClassID was in a cart sale where the credit card charge was "Transfer Credit Only"
isCharged  = 1 this ClassID was in a cart sale where the credit card charge "Succeeded". The whole cart was bought.
   Note: isCredited ("Transfer Credit Only") and isCharged ("Succeeded") are the only two types. No declined payments.

isZeroCharge
  = 1 this classID has isCharged=1 with "Succeeded" credit card charge, but the total charged was 0
  Issue: 5 transactions seem to be errors. It charged the card 0 but it was never in any ShoppingCartID (NULL cart)

isCheckedIn
  = 1 the UserID matching this purchased ClassID + SalesOrderID did check in to the class (checkinstatus = "YES")
  = 0 the UserID didn't check in (checkinstatus <> "YES")

isFinished = the UserID matching this purchased ClassID + SalesOrderID shows EnrollmentStatus = "Finished"
isRefunded = the User in this class shows EnrollmentStatus = "Transfered" meaning requested a refund
  Note: other status are "Active" (still in class, not common) and "Credited" (use isCredited = 1 which is similar)

*/



---1450 rows of shopping cart details (entire table)
-- One line is one class added to a shopcart. Shopcart can have multiple classes at once.
SELECT * from dbo.[FactBookingsAudit]
order by ShoppingCartID


---748 rows resulted in a saleOrder. 740 have isCharged=1 + 8 have isCredited=1 (from other class)
SELECT * from dbo.[FactBookingsAudit]
where SalesOrderID > 0  --or IS NOT NULL
order by ClassID


-- Here are 50 rows of cart transactions with invalid ClassID (ClassID not in DimClass, or isZeroCharge order error, see description above)
-- Example bad ClassID: 59 69 71 88 89, others.  Check in original Class Data table to verify; it's not there. 
SELECT * from dbo.[FactBookingsAudit]
where isValidClass=0
order by ShoppingCartID

-- Here are 5 classes added to a cart after that class already started. Ex: 82, 55, 33 minutes after class began. 
SELECT * from dbo.[FactBookingsAudit]
where MinInCartUntilClass < 0  -- or isLateCartAdd = 1
order by MinInCartUntilClass asc

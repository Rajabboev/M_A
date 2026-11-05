SELECT s.store_name , p.Category, round(sum(f.NetAmount), 2) AS revenue
FROM retailuz.sales f
JOIN retailuz.product p ON p.ProductKey = f.ProductKey
JOIN retailuz.store s on f.storekey =s.storekey
GROUP BY s.store, p.Category
ORDER BY revenue 
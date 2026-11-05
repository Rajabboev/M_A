SELECT p.Category, round(sum(f.NetAmount), 2) AS revenue
FROM retailuz.sales
JOIN retailuz.product ON p.ProductKey = f.ProductKey
GROUP BY p.Category
ORDER BY revenue 
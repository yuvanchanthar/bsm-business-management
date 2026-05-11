```json
{
  "_id": "651f1b2b8e4b2a3c4d5e6f7a",
  "deliveryId": "BSM-1696512000000",
  "customerName": "Sivaji Mills",
  "timestamp": "2023-10-05T14:30:00.000Z",
  "crewLeader": "Rajesh Kumar",
  "priority": "HIGH",
  "products": [
    {
      "name": "Raw Silk",
      "quantity": 10.5,
      "unit": "KG",
      "pricingType": "Per KG",
      "pricePerUnit": 500.0,
      "totalAmount": 5250.0
    },
    {
      "name": "Cotton Yarn",
      "quantity": 20,
      "unit": "Bags",
      "pricingType": "Per Bag",
      "pricePerUnit": 1200.0,
      "totalAmount": 24000.0
    }
  ],
  "financials": {
    "subtotal": 29250.0,
    "tax": 0.0,
    "grandTotal": 29250.0,
    "currency": "INR"
  },
  "status": "COMPLETED",
  "metadata": {
    "source": "BSM Logistics App",
    "version": "2.0.0"
  }
}
```

### Schema Explanation:
- **`deliveryId`**: Primary user-facing reference (timestamp-based).
- **`products`**: An array of sub-documents, each containing its own pricing logic and totals.
- **`financials`**: Summary object for easy querying of revenue metrics.
- **`status`**: Track lifecycle (DRAFT, PENDING, COMPLETED).

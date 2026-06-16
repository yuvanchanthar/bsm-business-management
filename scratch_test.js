
  const paymentStats = [
    { _id: '60c72b2f9b1d8b1f8c8b4567', total: 4000 }
  ];
  
  const allCustomers = [
    { _id: { toString: () => '60c72b2f9b1d8b1f8c8b4567' }, openingBalance: 10000 }
  ];
  
  let customerMap = {};
  allCustomers.forEach(c => {
    const cid = c._id.toString();
    customerMap[cid] = Number(c.openingBalance) || 0;
  });
  console.log('Seed Map:', customerMap);
  
  paymentStats.forEach(item => {
    if (item._id) customerMap[item._id.toString()] = (customerMap[item._id.toString()] || 0) - item.total;
  });
  
  console.log('After payments:', customerMap);
  
  let pendingAmount = 0, advanceAmount = 0;
  Object.values(customerMap).forEach(bal => {
    if (bal > 0) pendingAmount += bal;
    else if (bal < 0) advanceAmount += Math.abs(bal);
  });
  
  console.log('Advance:', advanceAmount);

***Price a Commodity Storage Contract***

Problem Statement:

You need to create a prototype pricing model that can go through further validation and testing before being put into production. Eventually, this model may be the basis for fully automated quoting to clients, but for now, the desk will use it with manual oversight to explore options with the client. 
You should write a function that is able to use the data you created previously to price the contract. The client may want to choose multiple dates to inject and withdraw a set amount of gas, so your approach should generalize the explanation from before. Consider all the cash flows involved in the product.
The input parameters that should be taken into account for pricing are:
1. Injection dates. 
2. Withdrawal dates.
3. The prices at which the commodity can be purchased/sold on those dates.
4. The rate at which the gas can be injected/withdrawn.
5. The maximum volume that can be stored.
6. Storage costs.
Write a function that takes these inputs and gives back the value of the contract. You can assume there is no transport delay and that interest rates are zero. Market holidays, weekends, and bank holidays need not be accounted for. Test your code by selecting a few sample inputs.

What I Did:

I developed a **Python function to calculate the value of a gas storage contract** using the forecasted prices from Task 1.  

**Key steps:**
- Defined contract value as:  
  `contract_value = revenue − total_costs`  
  where `revenue = (Sell Price forecasted − Buy Price forecasted) × Quantity` and `total_costs = Storage Costs + Other Fees`.
- Handled injections and withdrawals on specified dates.
- Ensured volumes did not exceed maximum capacity.
- Selected forecasted or historical prices for transactions.
- Tested the function with example data to compute total contract value.

**Skills gained:** Financial modeling, algorithm design, integrating predictive data into decision-making workflows.

# Project P6: Customer 360

**Class 9 · S/4HANA APIs and destinations (clean core in practice)**

**Goal:** one answer per customer that mixes two systems. The customer's name, industry and address come live from S/4HANA. The calls, visits and deals come from your own CAP database. Nothing from S/4HANA is copied, and no URL or password sits in your code.

**Time:** about 90 minutes.

**You need:** class 9. From earlier classes: entities and services (class 1 and 2), `before`, `on` and `after` handlers (class 5), functions (class 6). This project starts from its own starter, so you do not need earlier projects finished.

---

## The business story

Your sales team logs every **interaction** with a customer (a call, a visit, an email, a meeting) and every **opportunity** (a deal they hope to win). Both are new data, so they live in your CAP app.

The **customers** themselves already exist in S/4HANA, with their names and addresses. The finance team, the warehouse and the sales team all use that same customer. If you copy it into your app, the two copies drift apart the day someone changes an address. So you read it, live, every time.

## New words

- **API:** a door one system opens so other systems can read or change its data.
- **Business partner:** S/4HANA's word for a customer, a supplier or a contact person. Each has a number, like `1000001`.
- **SAP Business Accelerator Hub (api.sap.com):** SAP's catalogue of every public API, with a free sandbox to try them.
- **Sandbox:** a test S/4HANA system that SAP runs on the internet. Anyone with an API key can read from it.
- **API key:** a long secret text that proves who you are to the sandbox.
- **EDMX:** the file that describes an OData API: its entities, fields and keys.
- **`cds import`:** turns an EDMX file into a CDS model CAP can use, and registers it in package.json.
- **Remote service:** a service that lives in another system. CAP talks to it with `cds.connect.to`.
- **Mocking:** CAP pretends to be the remote system, using CSV files, so you can work offline.
- **Virtual element:** a field in your service that is not stored in the database. Your code fills it.
- **Destination:** a saved connection on BTP: the other system's address and how to log in.
- **Destination service:** the BTP service your app asks "where is S4_SANDBOX, and how do I log in?"
- **Connectivity service:** needed only when the other system sits in a company network behind a Cloud Connector. The sandbox is on the internet, so this project does not need it.
- **Profile:** a named set of settings, chosen with `--profile`, for example `sandbox` or `hybrid`.

## The rules

| # | Rule | How you build it |
| --- | --- | --- |
| 1 | Customers are read from S/4HANA, never copied | `cds import`, a projection, an `on READ` handler |
| 2 | Every interaction and opportunity shows the customer's name | A `virtual` field, filled in an `after READ` handler |
| 3 | You cannot log an interaction or a deal for a customer that does not exist | A `before CREATE` handler that asks S/4HANA |
| 4 | One request gives the full picture of a customer | A function, `customer360` |
| 5 | No URL, API key or password in the code | A BTP destination and the `hybrid` profile |

---

## Step 1: see the problem (5 min)

1. Clone the starter and run `cds watch` (see the readme).
2. Open `test.http`. Send **All interactions**. Every row has a `customerID` like `1000001`, but **no name**. Your sales rep does not know who `1000001` is.
3. Send the last request, the one with customer `9999999`. **It is saved.** That customer does not exist anywhere.

---

## Step 2: get the API from SAP (10 min)

1. Log in to [api.sap.com](https://api.sap.com). Search for **Business Partner (A2X)**. Its technical name is `API_BUSINESS_PARTNER`.
2. Open **API Specification** and download the **EDMX** file.
3. Drag the file into the root folder of your project in BAS.
4. While you are on api.sap.com, click **Show API Key** at the top of any API page and copy the key. You need it in step 8. Keep it secret.

Now import it:

```sh
cds import API_BUSINESS_PARTNER.edmx
```

**Check** what changed:

- A new file `srv/external/API_BUSINESS_PARTNER.csn`. This is the API as a CDS model.
- `package.json` has a new block, `cds.requires.API_BUSINESS_PARTNER`, with `"kind": "odata-v2"`. That tells CAP: "this is a remote OData V2 service".

You can delete the `.edmx` file now. CAP only needs the `.csn`.

---

## Step 3: expose customers in your service (10 min)

Replace `srv/customer360-service.cds` with this:

```cds
using crm from '../db/schema';
using { API_BUSINESS_PARTNER as S4 } from './external/API_BUSINESS_PARTNER';

service Customer360Service {

  // Our own data, stored in CAP. Each row gets the customer name from S/4HANA.
  entity Interactions as projection on crm.Interactions {
    *,
    virtual customerName : String(81) @title: 'Customer name'
  };

  entity Opportunities as projection on crm.Opportunities {
    *,
    virtual customerName : String(81) @title: 'Customer name'
  };

  // Customers, read live from S/4HANA. Never copied into our database.
  @readonly entity Customers as projection on S4.A_BusinessPartner {
    key BusinessPartner         as ID,
        BusinessPartnerFullName as name,
        BusinessPartnerCategory as category,
        Industry                as industry,
        CreationDate            as createdOn
  };

  // Customer addresses, also read live from S/4HANA
  @readonly entity CustomerAddresses as projection on S4.A_BusinessPartnerAddress {
    key BusinessPartner as customerID,
    key AddressID       as addressID,
        StreetName      as street,
        HouseNumber     as houseNumber,
        PostalCode      as postalCode,
        CityName        as city,
        Country         as country
  };

  // The "360" answer: one customer, everything we know, from both systems
  type CustomerOverview {
    ID           : String(10);
    name         : String(81);
    industry     : String(10);
    city         : String(40);
    country      : String(3);
    interactions : Integer;
    lastContact  : Date;
    nextFollowUp : Date;
    openPipeline : Decimal(12,2);
    wonValue     : Decimal(12,2);
  }

  function customer360(ID : String(10)) returns CustomerOverview;
}
```

### What each part does

| Code | Meaning |
| --- | --- |
| `using { API_BUSINESS_PARTNER as S4 }` | Load the imported API and give it a short name, `S4`. |
| `virtual customerName` | A field the client can read, but it is not a column in the database. Your code fills it in step 5. |
| `projection on S4.A_BusinessPartner` | Show only 5 of the 80 fields of a business partner, with friendly names. |
| `BusinessPartner as ID` | Rename the field. The client sees `ID`, S/4HANA still gets `BusinessPartner`. |
| `@readonly` | Our app may only read customers. Changing them is S/4HANA's job. |
| `type CustomerOverview { ... }` | The shape of the answer of the `customer360` function. It is not a table. |

Save. `cds watch` restarts, and the terminal says `mocking API_BUSINESS_PARTNER`. There is no S/4HANA to call yet, so `cds watch` pretends to be one. Open `Customers`: the list is empty, because the mock has no data. Step 4 fills it.

---

## Step 4: mock S/4HANA with CSV files (5 min)

CAP mocks a remote service when it finds CSV files for it. The file names start with the service name, then a dash, then the entity name.

Create `srv/external/data/API_BUSINESS_PARTNER-A_BusinessPartner.csv`:

```csv
BusinessPartner;BusinessPartnerFullName;BusinessPartnerCategory;Industry;CreationDate
1000000;Inlandkunde DE 1;2;RETAIL;2017-01-12
1000001;Domestic US Customer 1;2;RETAIL;2017-03-04
1000002;Domestic Customer GB 1;2;SERVICE;2018-05-21
1000003;Domestic Customer IN 1;2;MANUF;2019-08-30
1000004;Domestic Customer JP 1;2;MANUF;2020-02-14
```

Create `srv/external/data/API_BUSINESS_PARTNER-A_BusinessPartnerAddress.csv`:

```csv
BusinessPartner;AddressID;StreetName;HouseNumber;PostalCode;CityName;Country
1000000;22001;Lindenstrasse;12;69190;Walldorf;DE
1000001;22002;Market Street;400;94105;San Francisco;US
1000002;22003;King Street;25;M1 4PB;Manchester;GB
1000003;22004;MG Road;88;560001;Bengaluru;IN
1000004;22005;Chuo-dori;3-1;104-0061;Tokyo;JP
```

The CSV files use the **S/4HANA field names**, not your short names. They fill the mock of S/4HANA, not your service.

**Check:** the terminal lists both files under `init from`. Open `Customers` on the index page. You see 5 customers. The CSVs only have a few columns; the other fields of a business partner stay empty, and that is fine.

---

## Step 5: send reads to S/4HANA and add the names (15 min)

Create a new file `srv/customer360-service.js`. It must have the **same name** as `srv/customer360-service.cds`, so CAP finds it.

```js
import cds from '@sap/cds'

export default class Customer360Service extends cds.ApplicationService { async init() {

  const { Interactions, Opportunities, Customers, CustomerAddresses } = this.entities

  // Connect to S/4HANA. Where it is (mock, sandbox or destination) comes from package.json, not from this code.
  const S4 = await cds.connect.to('API_BUSINESS_PARTNER')
  const { destination, url, path = '' } = S4.options.credentials ?? {}
  console.log(`🔌 API_BUSINESS_PARTNER → ${destination ? `BTP destination '${destination}' + ${path}` : url ?? 'the local mock'}`)

  // 1. Customers and addresses are not in our database: send the query to S/4HANA
  this.on('READ', [Customers, CustomerAddresses], async (req) => {
    console.log(`\n🏢 ${req.target.name.split('.').pop()}: asking S/4HANA`)
    return S4.run(req.query)
  })

  // 2. Our rows only hold a customer number. Add the name from S/4HANA, with ONE call for all rows.
  this.after('READ', [Interactions, Opportunities], async (result) => {
    const rows = (Array.isArray(result) ? result : [result]).filter(r => r?.customerID)
    if (!rows.length) return
    const ids = [...new Set(rows.map(r => r.customerID))]
    const customers = await S4.run(SELECT.from(Customers).columns('ID', 'name').where({ ID: { in: ids } }))
    const names = Object.fromEntries(customers.map(c => [c.ID, c.name]))
    for (const r of rows) r.customerName = names[r.customerID]
    console.log(`👤 Added ${customers.length} customer name(s) from S/4HANA to ${rows.length} row(s)`)
  })

  return super.init()
}}
```

### What each part does

| Code | Meaning |
| --- | --- |
| `async init()` | `init` is `async` this time, because connecting to S/4HANA takes a moment and we `await` it. |
| `cds.connect.to('API_BUSINESS_PARTNER')` | "Give me the remote service with this name." CAP reads package.json to find out where it is. |
| `S4.options.credentials` | Where CAP will send the calls. Empty when mocked. We only print it, so you can see it in the terminal. |
| `this.on('READ', [Customers, CustomerAddresses], ...)` | "When someone reads customers, do not look in my database. Run this instead." |
| `S4.run(req.query)` | Send the same query to S/4HANA. CAP turns `ID` back into `BusinessPartner` and OData V4 into V2 for you. |
| `new Set(...)` | A list with no duplicates. Two notes about the same customer need only one name. |
| `where({ ID: { in: ids } })` | One call for all customers at once, not one call per row. Fewer calls, faster app. |
| `Object.fromEntries(...)` | Builds a lookup like `{ '1000001': 'Domestic US Customer 1' }`. |

**Check:** in `test.http`, send:

- **Customers, read live from S/4HANA**: 5 customers. The terminal prints `🏢 Customers: asking S/4HANA`.
- **Interactions, now with the customer name**: every row has `customerName`.

> **Watch out:** when you use `$select`, include `customerID`. Without it, the handler has no number to look up, and `customerName` stays empty.

---

## Step 6: refuse unknown customers (10 min)

In the same file, add this block **above** `return super.init()`:

```js
  // 3. Before we save anything, check that the customer really exists in S/4HANA
  this.before(['CREATE', 'UPDATE'], [Interactions, Opportunities], async (req) => {
    const { customerID } = req.data
    if (!customerID) return   // an update that does not change the customer
    const customer = await S4.run(SELECT.one.from(Customers, customerID).columns('ID'))
    if (!customer) req.error(400, `Customer ${customerID} does not exist in S/4HANA`, 'customerID')
  })
```

| Code | Meaning |
| --- | --- |
| `this.before(['CREATE', 'UPDATE'], ...)` | Run before a new row is saved, and before a row is changed. |
| `if (!customerID) return` | An update may change only the summary. Then there is nothing to check. |
| `SELECT.one.from(Customers, customerID)` | Ask for the one customer with this key. Returns `undefined` if there is none. |
| `req.error(400, ..., 'customerID')` | Refuse the request, and point the message at the `customerID` field. |

**Check:** send the request with customer `9999999` again. It now fails with `400` and `Customer 9999999 does not exist in S/4HANA`. Send **Log a new call** for customer `1000002`. It still works.

---

## Step 7: the 360 function (15 min)

Add this block **above** `return super.init()` too:

```js
  // 4. The 360 view: master data from S/4HANA + our own data from CAP, in one answer
  this.on('customer360', async (req) => {
    const { ID } = req.data
    console.log(`\n🔭 customer360 for ${ID}`)

    // From S/4HANA
    const customer = await S4.run(SELECT.one.from(Customers, ID))
    if (!customer) return req.error(404, `Customer ${ID} does not exist in S/4HANA`)
    const address = await S4.run(SELECT.one.from(CustomerAddresses).where({ customerID: ID }))

    // From our own database
    const contacts = await SELECT.one.from(Interactions).where({ customerID: ID })
      .columns('count(*) as interactions', 'max(contactDate) as lastContact')
    const next = await SELECT.one.from(Interactions).where({ customerID: ID, followUp: { '!=': null } })
      .columns('min(followUp) as nextFollowUp')
    const deals = await SELECT.from(Opportunities).where({ customerID: ID })
      .columns('stage', 'sum(value) as total').groupBy('stage')
    const total = (stage) => Number(deals.find(d => d.stage === stage)?.total ?? 0)

    return {
      ID,
      name:         customer.name,
      industry:     customer.industry,
      city:         address?.city,
      country:      address?.country,
      interactions: contacts.interactions,
      lastContact:  contacts.lastContact,
      nextFollowUp: next?.nextFollowUp,
      openPipeline: total('Open'),
      wonValue:     total('Won')
    }
  })
```

### What each part does

| Code | Meaning |
| --- | --- |
| `S4.run(SELECT ...)` | Goes to S/4HANA. |
| `SELECT ...` with no `S4.run` | Goes to **our** database. Same query language, different system. |
| `count(*)`, `max(...)`, `min(...)`, `sum(...)` | The database counts and adds up for us, so we do not loop in JavaScript. |
| `.groupBy('stage')` | One total per stage: Open, Won and Lost. |
| `address?.city` | `?.` means "if there is an address". A customer with no address gives `undefined`, not a crash. |
| `return { ... }` | The answer. Its fields match `type CustomerOverview` in the .cds file. |

**Check:** send `GET {{svc}}/customer360(ID='1000001')`. You get:

```json
{
  "ID": "1000001",
  "name": "Domestic US Customer 1",
  "industry": "RETAIL",
  "city": "San Francisco",
  "country": "US",
  "interactions": 2,
  "lastContact": "2026-10-28",
  "nextFollowUp": "2026-11-20",
  "openPipeline": 45000,
  "wonValue": 18000
}
```

Name, industry and city came from S/4HANA. The rest came from your database. Then try `ID='9999999'`: you get `404`.

---

## Step 8: the real sandbox, through a destination (20 min)

So far S/4HANA was a mock. Now you call SAP's real sandbox. There are two ways. Do both, in this order.

### 8a. Quick test with your API key (5 min)

Add a `[sandbox]` profile to the `API_BUSINESS_PARTNER` block in `package.json`, so it looks like this:

```json
"cds": {
  "requires": {
    "API_BUSINESS_PARTNER": {
      "kind": "odata-v2",
      "model": "srv/external/API_BUSINESS_PARTNER",
      "[sandbox]": {
        "credentials": {
          "url": "https://sandbox.api.sap.com/s4hanacloud/sap/opu/odata/sap/API_BUSINESS_PARTNER"
        }
      }
    }
  }
}
```

Create a file `.cdsrc-private.json` in the project root. **Check that `.gitignore` lists it**, so it never goes to GitHub:

```json
{
  "requires": {
    "API_BUSINESS_PARTNER": {
      "[sandbox]": {
        "credentials": {
          "headers": { "APIKey": "<paste your API key from api.sap.com here>" }
        }
      }
    }
  }
}
```

Run `cds watch --profile sandbox`. Send **Customers** and **customer360** again. The names are now real sandbox data. Your interactions are still in your own database.

This works, but the key sits in a file on your machine. In a real company, every developer would need it. A destination fixes that.

### 8b. A BTP destination (15 min)

1. **Create the destination.** In the BTP cockpit, open your subaccount, then **Connectivity > Destinations > Create Destination**:

   | Field | Value |
   | --- | --- |
   | Name | `S4_SANDBOX` |
   | Type | `HTTP` |
   | URL | `https://sandbox.api.sap.com` |
   | Proxy Type | `Internet` |
   | Authentication | `NoAuthentication` |

   Under **Additional Properties**, click **New Property** and add `URL.headers.APIKey` with your API key as the value. Save, then click **Check Connection**. A 404 or 401 answer from the sandbox root is fine; it means BTP reached the system.

2. **Add a `[hybrid]` profile** next to `[sandbox]` in `package.json`. It holds only a name and a path, no secret:

   ```json
   "[hybrid]": {
     "credentials": {
       "destination": "S4_SANDBOX",
       "path": "/s4hanacloud/sap/opu/odata/sap/API_BUSINESS_PARTNER"
     }
   }
   ```

3. **Create a Destination service instance and bind it.** In the BAS terminal:

   ```sh
   cf login                                   # your trial API endpoint, e.g. https://api.cf.us10-001.hana.ondemand.com
   cf create-service destination lite customer-360-destination
   cds bind -2 customer-360-destination
   ```

   `cds bind` writes only a *reference* to a service key into `.cdsrc-private.json`. No secret goes into your project.

4. **Run it:**

   ```sh
   cds watch --profile hybrid
   ```

   The terminal shows `🔌 API_BUSINESS_PARTNER → BTP destination 'S4_SANDBOX' + /s4hanacloud/...`. Send `customer360(ID='1000001')` again.

**This is the point of the class.** Point the destination at your company's real S/4HANA, and not one line of your code changes.

Run `cds watch` with no profile to go back to the mock at any time.

---

## Step 9: AI task in BAS (10 min)

Ask Claude in BAS:

> Explain srv/customer360-service.js to a beginner. Which lines call S/4HANA and which lines call our own database? Then make customer360 also return the number of open opportunities. Show me the change before you make it.

Then:

1. Read the change. Did it touch the `CustomerOverview` type in the .cds file too? It must, or the new field is not sent.
2. Send `customer360(ID='1000003')` and check the new number by hand against `db/data/crm-Opportunities.csv`.

---

## Your tasks

Do these on your own. Use Claude in BAS if you get stuck, and check every change it makes.

1. **City on every interaction.** Add a second virtual field, `customerCity`, to Interactions. Fill it in the same `after READ` handler, with **one** call to `CustomerAddresses` for all rows.
2. **No deal for a blocked customer.** Add `BusinessPartnerIsBlocked as blocked` to the `Customers` projection. In the `before` handler, refuse an Opportunity when the customer is blocked. Add a sixth customer, blocked, to the mock CSV to test it.
3. **A Fiori list for customers.** `app/annotations.cds` already has `@UI.LineItem` for Customers. Add `@UI.SelectionFields: [ industry ]` and open Customers in the Fiori preview. Filter by industry. Watch the terminal: the filter goes to S/4HANA.
4. **Overdue follow-ups.** Add a function `overdueFollowUps()` that returns the interactions whose `followUp` date is before today, with the customer name.

---

## Done when

- [ ] `cds watch` works offline, with S/4HANA mocked
- [ ] Interactions and Opportunities show `customerName`
- [ ] Customer `9999999` is refused with `400`
- [ ] `customer360(ID='1000001')` returns data from both systems
- [ ] `cds watch --profile hybrid` reads customers from the sandbox through `S4_SANDBOX`
- [ ] No URL with a key, and no API key, is in any committed file (`git status` and `git diff` to check)
- [ ] Your tasks work, and are pushed to your own GitHub repo

---

## Common errors

| What you see | Why | Fix |
| --- | --- | --- |
| `No credentials configured for API_BUSINESS_PARTNER` | You ran `npm start` or `cds serve`, which do not mock | Use `cds watch` (it mocks), or add `--profile sandbox` or `hybrid` |
| `Customers` is empty, but no error | CSV file name or folder is wrong | Exactly `API_BUSINESS_PARTNER-A_BusinessPartner.csv`, in `srv/external/data` |
| `customerName` is empty | `$select` without `customerID` | Always select `customerID` too |
| Handlers never run | The .js file name does not match the .cds file | `customer360-service.cds` with `customer360-service.js` |
| `await is only valid in async functions` | `init()` is not `async` | Write `async init()` |
| `Destination 'S4_SANDBOX' not found` | Name mismatch, or another subaccount | Match the name exactly; create the instance in the same subaccount |
| `401 Unauthorized` | API key missing or wrong | Check `URL.headers.APIKey` in the destination, or `APIKey` in `.cdsrc-private.json` |
| `cds bind` fails | Not logged in to Cloud Foundry | `cf login`, then `cf target -s dev` |
| `403` or `405` when you create a customer | The sandbox is read-only | Read customers only; write to your own interactions |

---

## Next class

The app works, but only in BAS. Class 10 tests it with `cds.test`, deploys it to Cloud Foundry with a real login, and builds a CI/CD pipeline. Customer 360 is a good candidate for that deploy.

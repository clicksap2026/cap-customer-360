# Customer 360 in SAP CAP (Project P6)

A sales team wants one screen per customer: who the customer is, where they are, when we last spoke to them, and how much business is open. The customer master data already lives in S/4HANA. Our app must **not copy it**. It reads it live, and stores only what S/4HANA does not have: our calls, visits and deals.

A practice project from the **clickERP** live SAP CAP course, for **class 9: S/4HANA APIs and destinations**.

## Start in SAP Business Application Studio

Open a **Full Stack Cloud Application** dev space and a new terminal:

```sh
git clone https://github.com/clicksap2026/cap-customer-360.git
cd cap-customer-360
git checkout p6-start
npm install
cds watch
```

Open the link that BAS shows for port 4004.

## Branches

| Branch | What it holds |
| --- | --- |
| `p6-start` | The starter. Interactions and Opportunities, with only a customer number. No S/4HANA yet. |
| `main` | The finished project. Compare with it when you are done, not before. |

## What is in the starter

- `db/schema.cds`: **Interactions** (calls, visits, emails, meetings) and **Opportunities** (deals), each with a `customerID`: the S/4HANA business partner number
- `db/data/`: 6 interactions and 5 opportunities for customers `1000000` to `1000003`
- `srv/customer360-service.cds`: the Customer360Service
- `app/annotations.cds`: columns for the Fiori preview
- `test.http`: read, create, and one request with a customer number that does not exist. In the starter **it is saved**. That is one of the problems you fix.

Follow [guides/p6-customer-360.md](guides/p6-customer-360.md) step by step.

## Run the finished project

```sh
git checkout main
npm install
cds watch                      # S/4HANA is mocked with CSV files, works offline
cds watch --profile sandbox    # the real SAP API sandbox, with your API key
cds watch --profile hybrid     # the sandbox through the BTP destination S4_SANDBOX
```

For `sandbox`, copy `cdsrc-private.sample.json` to `.cdsrc-private.json` and paste your API key from api.sap.com. For `hybrid`, follow step 8 of the guide. No URL secret or API key is ever committed: `.cdsrc-private.json` is in `.gitignore`.

---

🎓 Want live, instructor-led SAP training? Request a live session here: https://forms.gle/ovT9EgQquL5ERW2c6

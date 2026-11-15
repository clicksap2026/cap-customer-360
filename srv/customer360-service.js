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

  // 3. Before we save anything, check that the customer really exists in S/4HANA
  this.before(['CREATE', 'UPDATE'], [Interactions, Opportunities], async (req) => {
    const { customerID } = req.data
    if (!customerID) return   // an update that does not change the customer
    const customer = await S4.run(SELECT.one.from(Customers, customerID).columns('ID'))
    if (!customer) req.error(400, `Customer ${customerID} does not exist in S/4HANA`, 'customerID')
  })

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

  return super.init()
}}

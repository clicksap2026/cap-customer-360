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

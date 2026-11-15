using crm from '../db/schema';

service Customer360Service {
  entity Interactions  as projection on crm.Interactions;
  entity Opportunities as projection on crm.Opportunities;
}

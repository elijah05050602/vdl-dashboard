# Client and party registry

A firm-wide list of every client, adverse party, opposing counsel, witness and related party
the firm deals with, linked to matters by role. The conflict check searches it.

## Where to find it

- **Clients and parties** in the global menu (`/clients_and_parties`): search, add and edit
  people, companies and government agencies, with TIN, contact details and alternate names.
- **Parties** in each matter's menu (`/projects/<matter>/parties`): link registry entries to
  the matter as Client, Adverse party, Opposing counsel, Witness or Related party.

## Data

| Table | Model | Holds |
| --- | --- | --- |
| `parties` | `Party` | kind (person, organization, government), name, TIN (digits only), email, phone, address, notes |
| `party_aliases` | `PartyAlias` | other names: maiden, former or married name, nickname, trade name, former company name, abbreviation |
| `matter_parties` | `MatterParty` | project, party, role, notes. One row per party and role on a matter |

A matter's client is the `MatterParty` with role `client` (a matter can have several).
Deleting a matter removes its links. A party that is still linked to a matter cannot be deleted.

## Permissions

| Permission | Scope | Default |
| --- | --- | --- |
| View the client and party registry | global | Standard global role (every user) |
| Add and edit clients and parties in the registry | global | Standard global role (every user) |
| View the parties of a matter | matter | roles that can view matter attributes |
| Link and unlink parties on a matter | matter | roles that can edit matter attributes |

Admins can narrow these under Administration, Users and permissions, Roles and permissions.
Party pages only list matters the viewer can see, plus a count of the others.

## Updating an existing install

Run `bin/rails db:migrate`. The migration creates the tables and grants the permissions above
to existing roles.

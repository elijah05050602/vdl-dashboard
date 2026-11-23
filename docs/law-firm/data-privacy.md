# Data privacy

VDL holds personal and often sensitive information about clients, opposing parties and witnesses. The Data Privacy Act of 2012 (RA 10173), its Implementing Rules and the National Privacy Commission (NPC) circulars apply to the firm as a personal information controller. This page lists what the dashboard does to help and what the firm still has to do itself. It is not legal advice on compliance.

The code lives in `modules/data_privacy`.

## Consent records

Each matter has a **Data privacy** page in its menu. For every person whose personal information the matter holds, record:

- the data subject's name and relationship to the matter (client, witness, opposing party and so on)
- the date consent was given
- the scope: the purposes, the kinds of information and who it may be shared with
- whether it covers sensitive personal information (Sec. 3(l), for example health, government IDs or court records)
- the signed consent form, uploaded as a file

When someone withdraws consent, use **Withdraw** and enter the date and how it was received. The record stays in the list as withdrawn, so the firm can show when consent ended. Only administrators can delete a consent record.

Consent is not the only lawful basis. Processing that is needed for a legal claim or court proceedings (Sec. 13(f)) does not depend on consent, so a withdrawal does not by itself force the firm to delete case files. Write the basis for continued processing in the withdrawal notes.

Permissions (Administration, Roles and permissions, module "Data privacy"):

- *View data privacy consents*: see the page and download the forms.
- *Manage data privacy consents*: record, edit and withdraw consents.

On upgrade, both permissions are given to every role that can edit work packages. On a new database, the Member role gets both. The Reader role gets neither.

## Audit trail

**Administration, Audit trail** lists who did what, and when:

| Event | Recorded when |
|---|---|
| Viewed | someone opens a matter page or a work package (repeat views by the same person within a minute count once) |
| Changed | someone saves, creates or deletes anything, in the browser or through the API |
| Exported | someone exports a list or a work package (CSV, Excel, PDF and similar) |
| Downloaded | someone downloads an attached file, including finished exports and consent forms |
| Signed in | someone signs in (after the 2FA code, when 2FA is on) |

Each entry keeps the user, matter, record, the address of the request and the IP address. Filter by user, matter, event and dates, and download the result as CSV. Each matter's Data privacy page links to its own trail for administrators.

Entries cannot be changed from the application. They keep the user's and matter's names, so they still make sense after either is deleted. Entries older than five years are removed every night. Set `OPENPROJECT_AUDIT__RETENTION__DAYS` to change that, or `0` to keep everything.

The trail complements, and does not replace, the work package and matter history that OpenProject already keeps.

## Confidential matters

Every matter is private by default (`default_projects_public` is off): only its members can see it. To keep a matter to the lawyers assigned to it:

1. Add only the assigned lawyers and staff as members, under **Members**. Do not add a group that holds the whole firm.
2. An administrator opens the matter's **Data privacy** page and clicks **Mark confidential**.

A confidential matter cannot be made public, and its work packages cannot be shared with people outside the matter. Only an administrator can remove the mark. Administrators can still see every matter, so keep the number of administrator accounts small.

## Two-factor authentication

In production, every user must set up two-factor authentication (an authenticator app or a security key) the first time they sign in. Development mode on a single PC is not affected. To turn it off on a server, set `OPENPROJECT_2FA_ENFORCED=false`.

Sessions end after 60 minutes without activity, and self-registration is off.

## What the firm still has to do

These are outside the software:

1. **Appoint a Data Protection Officer** (Sec. 21(b), NPC Advisory 2017-01) and publish their contact details.
2. **Register with the NPC** through its online registration system, if the firm meets the thresholds in NPC Circular 2022-04 (for example 250 or more employees, or processing sensitive personal information of 1,000 or more people). A law firm handling court records will often meet the sensitive information threshold.
3. **Write a privacy manual and a privacy notice** for clients, and use a consent form that matches the scope recorded here.
4. **Plan for breaches**: the NPC and affected people must be told within 72 hours of knowing about a breach (NPC Circular 16-03).
5. **Agree data sharing or outsourcing terms** with the hosting provider of the online server.
6. **Review the audit trail regularly**, for example monthly, and keep the review on file.

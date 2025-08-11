# 📘 Unofficial e‑Boekhouden Power BI Connector

Deze **onofficiële** Power BI-connector biedt een eenvoudige manier om gegevens vanuit e‑Boekhouden.nl te importeren en rapporteren in Power BI.

---

## 🔧 Wat doet deze connector?

- Facturen, mutaties en grootboekrekeningen ophalen  
- Balansen per grootboekrekening opvragen  
- Administraties en openstaande facturen ophalen  
- Historische data ophalen (zoals balansen over de laatste 2 jaar)

---

## 🔑 API-sleutel aanvragen

1. Log in op [e‑boekhouden.nl](https://e-boekhouden.nl).
2. Ga naar **Beheer → Inrichting → Koppelingen → API/SOAP**.
3. Maak een nieuwe **API-token** aan.
4. Geef een duidelijke naam en kies een vervaldatum.
5. Kopieer de gegenereerde API-sleutel.

Geen toegang? Neem contact op met e‑Boekhouden-support.

---

## 📦 Installatie

### 1. Plaats het connector-bestand

Plaats het bestand `eBoekhouden.mez` in:
```
Documents\Power BI Desktop\Custom Connectors\
```

### 2. Power BI instellen

- Ga naar **Bestand → Opties → Preview-functies**.
- Zet **"Custom data connectors"** aan.
- Herstart Power BI.

---

## 🚀 Connector gebruiken

1. Open Power BI.
2. Ga naar **Gegevens ophalen → Meer... → Unofficial e‑Boekhouden (API)**.
3. Plak je API-sleutel en klik op **Connect**.
4. Kies de gewenste dataset en parameters, klik **Laden**.

---

## 📌 Beschikbare functies

| Functie | Beschrijving |
|---------|--------------|
| `getInvoices(offset, limit)` | Facturen ophalen |
| `getMutations(offset, limit)` | Mutaties ophalen |
| `getLedgers()` | Grootboekrekeningen ophalen |
| `GetLedgerBalance(id, startDate, endDate)` | Balans grootboekrekening per periode |
| `getLedgerBalances()` | Balansen alle grootboekrekeningen (laatste 2 jaar) |
| `getAdministration()` | Administratiegegevens (alleen accountants) |

---

## ⚠️ Veelvoorkomende problemen

- **Authenticatiefout:** Zorg dat `TestConnection` gebruik maakt van `getSession()`.
- **EP_001 fout:** Alleen beschikbaar voor accountants. Vermijd `getAdministration()` als je geen accountant bent.
- **Datumformaat:** Gebruik `yyyy-MM-dd`.

---

## 💻 Bijdragen

Wil je bijdragen aan ontwikkeling?

- Fork en clone de repository
- Pas de `.pq` bestanden aan
- Test met Power BI Desktop
- Dien een pull request in

---

## 📄 Licentie

Deze connector valt onder de **MIT-licentie**. Gebruik is op eigen risico. Raadpleeg de [officiële e‑Boekhouden API-documentatie](https://api.e-boekhouden.nl/swagger/index.html).

---

Veel succes met data-analyse met e‑Boekhouden en Power BI! 🚀

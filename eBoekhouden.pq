// This file contains your Data Connector logic
[Version = "1.0.0"]
section eBoekhouden;

[DataSource.Kind="eBoekhouden", Publish="eBoekhouden.Publish"]
shared eBoekhouden.Contents = () =>
    let
        navTable = #table(
            {"Name", "Item", "Kind"},
            {
                {"Invoices",          eBoekhouden.getInvoices,           "Function"},
                {"Mutations",         eBoekhouden.getMutations,          "Function"},
                {"Invoice by ID",         eBoekhouden.getInvoice,          "Function"},
                {"Ledgers",           eBoekhouden.getLedgers,            "Function"},
                {"Relations",         eBoekhouden.getRelation,           "Function"},
                {"Products",          eBoekhouden.getProduct,            "Function"},
                {"Invoice templates", eBoekhouden.getInvoiceTemplate,    "Function"},
                {"Outstanding Invoices creditor", eBoekhouden.getOutstandingInvoicesCreditor, "Function"},
                {"Outstanding Invoices debtor", eBoekhouden.getOutstandingInvoicesDebtor, "Function"},
                {"Administration",    eBoekhouden.getAdministration,     "Function"},
                {"Ledger balance", eBoekhouden.GetLedgerBalance, "Function"},
                {"Balances of all ledgers over the past 2 years", eBoekhouden.getLedgerBalances, "Function"}
            }
        ),
        navigation = Table.ToNavigationTable(
            navTable,
            {"Name"},
            "Name",
            "Item",
            "Kind",
            "Item",
            "IsLeaf"
        )
    in
        navigation;

shared eBoekhouden.getSession = () =>
    let
        url = "https://api.e-boekhouden.nl/v1/session",
        apiKey = try Extension.CurrentCredential()[Key] otherwise error "No API key provided",
        jsonBody = Json.FromValue([ accessToken = apiKey, source = "powerBI" ]),
        options = [
            Headers = [
                #"Content-Type" = "application/json",
                #"Accept" = "application/json"
            ],
            Content = jsonBody,
            ManualCredentials = true,
            ManualStatusHandling = {400, 401, 403, 500}
        ],
        rawResponse = Web.Contents(url, options),
        status = Value.Metadata(rawResponse)[Response.Status],
        bodyText = Text.FromBinary(rawResponse),
        parsed = if status < 300
                 then Json.Document(rawResponse)
                 else error "Auth failed (HTTP " & Text.From(status) & "): " & bodyText,
        token = try parsed[token] otherwise error "No token in response: " & bodyText
    in
        token;

// Centralized authenticated request
 eBoekhouden.AuthRequest = (relativePath as text, optional query as nullable record) =>
    let
        token = eBoekhouden.getSession(),
        url   = "https://api.e-boekhouden.nl" & relativePath,
        options = [
            Headers = [
                #"Content-Type"  = "application/json",
                #"Authorization" = token
            ],
            Query   = query,
            ManualCredentials = true
        ],
        result = Web.Contents(url, options)
    in
        result;

// Retrieve paged items endpoint
eBoekhouden.retrieveItems = (relativePath as text, offset as number, limit as number) =>
    let
        rawResponse = Json.Document(
            eBoekhouden.AuthRequest(relativePath, [offset = Text.From(offset), limit = Text.From(limit)])
        ),
        items = rawResponse[items],
        table = Table.FromRecords(items),
        sorted = Table.Sort(table, {{"date", Order.Descending}})
    in
        sorted;

// Exposed functions returning tables
shared eBoekhouden.getInvoices = (offset as number, limit as number) =>
    let
        tbl = eBoekhouden.retrieveItems("/v1/invoice", offset, limit),
        result = Table.TransformColumnTypes(tbl, {
            {"date", type date}, {"id", Int64.Type}, {"type", Int64.Type},
            {"invoiceNumber", type text}, {"ledgerId", Int64.Type}, {"amount", Currency.Type},
            {"entryNumber", type text}
        })
    in
        result;

shared eBoekhouden.getInvoice = (id as number) =>
    let
        raw = eBoekhouden.AuthRequest("/v1/invoice/" & Text.From(id))
    in
        raw;

shared eBoekhouden.getMutations = (offset as number, limit as number) =>
    let
        tbl = eBoekhouden.retrieveItems("/v1/mutation", offset, limit),
        result = Table.TransformColumnTypes(tbl, {
            {"date", type date}, {"id", Int64.Type}, {"type", Int64.Type},
            {"invoiceNumber", type text}, {"ledgerId", Int64.Type}, {"amount", Currency.Type},
            {"entryNumber", type text}
        })
    in
        result;

shared eBoekhouden.getLedgers = () =>
    let
        raw     = Json.Document(eBoekhouden.AuthRequest("/v1/ledger")),
        records = raw[items],
        tbl     = Table.FromRecords(records),
        changed = Table.TransformColumnTypes(tbl, {{"id", Int64.Type}, {"code", Int64.Type}}),
        filtered= Table.SelectRows(changed, each [code] <> null)
    in
        filtered;

eBoekhouden.lastMonths = () =>
    let
        StartMonth = Date.StartOfMonth(Date.AddMonths(Date.From(DateTime.LocalNow()), -23)),
        Months = List.Generate(
            ()=> StartMonth,
            each _ <= Date.From(DateTime.LocalNow()),
            each Date.AddMonths(_, 1)
        ),
        MonthPairs = Table.FromRecords(List.Transform(Months, each [Start =Date.ToText(_,"yyyy-MM-dd") , End = Date.ToText(Date.AddDays(Date.AddMonths(_, 1), -1), "yyyy-MM-dd")]))
    in
        MonthPairs;

shared eBoekhouden.GetLedgerBalance = (id as text, startDate as text, endDate as text) =>
    let
        raw = eBoekhouden.retrieveItems("/v1/ledger/" & id & "/balance", startDate, endDate),
        response = Json.Document(raw)
    in
        response;

shared eBoekhouden.getLedgerBalances = () =>
    let
        LedgerIDs = eBoekhouden.getLedgers()[id],
        MonthPairs = Table.ToRecords(eBoekhouden.lastMonths()),

        Combined = List.Combine(
            List.Transform(LedgerIDs, (ledger) =>
                List.Transform(MonthPairs, (pair) =>
                    [
                        id = ledger,
                        startDate = pair[Start],
                        endDate = pair[End]
                    ]
                )
            )
        ),

        RawResults = List.Transform(Combined, each 
            let 
                r = _,
                result = try eBoekhouden.GetLedgerBalance(Text.From(r[id]), r[startDate], r[endDate]) otherwise null
            in
                if result <> null and Record.FieldCount(result) > 0 then
                    Record.Combine({r, result})
                else
                    null
        ),

        Clean = List.RemoveNulls(RawResults),
        TableOut = Table.FromRecords(Clean),

        #"Changed Type" = Table.TransformColumnTypes(TableOut,{
            {"startDate", type date},
            {"endDate", type date},
            {"id", Int64.Type},
            {"code", Int64.Type},
            {"balance", Currency.Type}
        })
    in
        #"Changed Type";

shared eBoekhouden.getOutstandingInvoicesCreditor = () =>
    let
        raw      = Json.Document(eBoekhouden.AuthRequest("/v1/mutation/invoice/outstanding?credDeb=c")),
        records  = raw[items],
        table    = Table.FromRecords(records),
        result   = Table.TransformColumnTypes(table, {
            {"date", type date}, {"mutationId", Int64.Type}, {"totalAmount", Currency.Type}, {"paidAmount", Currency.Type}, {"outstandingAmount", Currency.Type},
            {"invoiceNumber", type text}, {"relationId", Int64.Type}
        })
    in
        result;

shared eBoekhouden.getOutstandingInvoicesDebtor = () =>
    let
        raw      = Json.Document(eBoekhouden.AuthRequest("/v1/mutation/invoice/outstanding?credDeb=d")),
        records  = raw[items],
        table    = Table.FromRecords(records),
        result   = Table.TransformColumnTypes(table, {
            {"date", type date}, {"mutationId", Int64.Type}, {"totalAmount", Currency.Type}, {"paidAmount", Currency.Type}, {"outstandingAmount", Currency.Type},
            {"invoiceNumber", type text}, {"relationId", Int64.Type}
        })
    in
        result;

shared eBoekhouden.getAdministration = () =>
    let
        result = Json.Document(eBoekhouden.AuthRequest("/v1/administration")),
        output =
            if result[HasError] then
                let
                    err = result[Error],
                    msg = if Record.HasFields(err, {"status", "code"}) and err[code] = "EP_001" then
                            error "Deze endpoint is alleen beschikbaar voor accountants. Neem contact op met e-Boekhouden als je denkt dat dit een fout is."
                          else
                            error Text.From(err)
                in
                    msg
            else
                let
                    records = result[Value][items],
                    table   = Table.FromRecords(records)
                in
                    table
    in
        output;
        

shared eBoekhouden.getInvoiceTemplate = () =>
    let
        raw = Json.Document(eBoekhouden.AuthRequest("/v1/invoiceTemplate")),
        records  = raw[items],
        table    = Table.FromRecords(records)
    in
        table;

shared eBoekhouden.getRelation = () =>
    let
        raw = Json.Document(eBoekhouden.AuthRequest("/v1/relation")),
        records  = raw[items],
        table    = Table.FromRecords(records)
    in
        table;

shared eBoekhouden.getProduct = () =>
    let
        raw = Json.Document(eBoekhouden.AuthRequest("/v1/product")),
        records  = raw[items],
        table    = Table.FromRecords(records)
    in
        table;

shared eBoekhouden.testTable = () =>
    let
        token = eBoekhouden.getSession(),
        result = #table({"Token"}, {{token}})
    in
        result;

// Data Source Kind description
 eBoekhouden = [
    TestConnection = (dataSourcePath) => { "eBoekhouden.getSession" },
    Authentication = [
        Key = [ Label = "e-Boekhouden API key", KeyLabel = "Plak je API key" ]
    ],
    Label = "e-Boekhouden (API)"
];

// Data Source UI publishing description
 eBoekhouden.Publish = [
    Beta       = true,
    Category   = "Finance",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl      = "https://powerbi.microsoft.com/",
    SourceImage       = eBoekhouden.Icons,
    SourceTypeImage   = eBoekhouden.Icons
];

eBoekhouden.Icons = [
    Icon16 = { Extension.Contents("eBoekhouden16.png"), Extension.Contents("eBoekhouden20.png"), Extension.Contents("eBoekhouden24.png"), Extension.Contents("eBoekhouden32.png") },
    Icon32 = { Extension.Contents("eBoekhouden32.png"), Extension.Contents("eBoekhouden40.png"), Extension.Contents("eBoekhouden48.png"), Extension.Contents("eBoekhouden64.png") }
];

// Navigation table helper
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
            [ NavigationTable.NameColumn    = nameColumn,
              NavigationTable.DataColumn    = dataColumn,
              NavigationTable.ItemKindColumn= itemKindColumn,
              Preview.DelayColumn           = itemNameColumn,
              NavigationTable.IsLeafColumn  = isLeafColumn ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

# Archive HTML

The program `archive-html` takes a list (CSV file) of URLs and enriches each row with the following data:

1. **metadata about the URL**
    - normalized version of the URL
    - domain name
2. **data about the archived HTML**:
    - hash of the URL, which is (a) the file name of the HTML fetched with minet and (b) identifier for the archived page's log and paths files.
    - timestamp of when minet fetched the HTML
    - timestamp of when the entire page was logged in the archive 

# Workflow

There are 3 stages of the archiving process.

Step 1. The Python script's CLI command `fetch` (1) cleans the data by normalizing the URL and determining the domain name, (2) hashes the URL with the same `md5` hash that minet uses, and (3) uses minet to fetch the HTML, which minet stores in a file named for the hashed URL. The result of this first step is an updated CSV file with the fields `normalized_url`, `domain`, `url_hash`, and `fetch_timestamp`.

Step 2. The bash script parses the updated file (outfile) and pulls data from the `url` and `url_hash` fields. It uses the bash command `wget` to archive each URL and saves the `wget` log in a file ending with the URL's hash, i.e. `log_63ae9729913978917c258e336579d9f4`. The script then appends the log file with a line declaring the time when the `wget` command was called. Finally, before moving onto the next URL, the bash script parses the log and extracts all the file paths `wget` created for the URL's archive, i.e. `paths_63ae9729913978917c258e336579d9f4`. (The first line of the `paths_` file is the web page's index.html)

Step 3. The python script's CLI command archive-time parses the last line of `log_` file, on which the archive's timestamp was recorded, and adds that data (`archive_timestamp`) to the CSV file.

```mermaid
flowchart LR
subgraph fetch
    start[cli.py fetch]
    style start fill:#f96

    parsefile[parse file]
    infile[/in-file\nCSV/]
    minetfetch[fetch URL]
    fetchhtml[/hash.html/]
    hash[hash normalized URL]
    outfile[/outfile\nCSV/]

    start--> parsefile
    parsefile<-.-|read\nall fields|infile
    parsefile-->minetfetch
    minetfetch-->fetchhtml
    parsefile-->hash
    minetfetch-->|write\nfetch_timestamp|outfile
    hash-->|write\nurl_hash, all fields|outfile
end

fetch-->wget
wget-->log

subgraph wget
    wgetscript[bash script]
    style wgetscript fill:#f96

    
    bashparseoutfile[parse outfile]
    wgetlog[/LOG_hash\ntxt/]
    wgetpaths[/PATHS_hash\ntxt/]
    wgettree[archive URL]
    archivedir[(archive)]

    wgetscript-->bashparseoutfile
    bashparseoutfile<-.-|read\nurl, url_hash|outfile
    bashparseoutfile-->wgettree
    bashparseoutfile-->wgetpaths
    bashparseoutfile-->wgetlog
    archivedir---wgettree
end

subgraph log
    last[cli.py archive-time]
    style last fill:#f96

    parselog[parse log]
    parseoutfile[parse outfile]
    finaloutfile[/outfile\nCSV/]

    last-->parselog
    last-->parseoutfile
    parselog<-.-|read\narchive_timestamp|wgetlog
    parselog-->|write\narchive_timestamp|finaloutfile
    parseoutfile<-.-|read\nall fields|outfile
    parseoutfile-->|write\nall fields|finaloutfile
end

```

The normalized URL is hashed using Python's native `md5` package.

```python
from hashlib import md5
hash_of_url = md5(str.encode(normalized_url)).hexdigest()
```

## The In-File
The in-file must be a CSV with headers and have at least the URL column.

### **Minimum Requirements of the In-File:**
|url|
|--|
|https://medialab.sciencespo.fr/activites/epo/|
|https://twitter.com/bu_unistra/status/1592121602480955392|
|https://www.dariah.eu/2022/10/10/mutual-learning-workshop-for-improving-cultural-heritage-bibliographical-data/|


### **Maximum Elements of the In-File Taken into Account**
The in-file CSV may contain many other columns and metadata, but the program `archive-html` will only parse the following data:
|normalized_url|domain|
|--|--|
|medialab.sciencespo.fr/activites/epo|medialab.sciencespo.fr|
|twitter.com/bu_unistra/status/1592121602480955392|huma-num.fr|
|dariah.eu/2022/10/10/mutual-learning-workshop-for-improving-cultural-heritage-bibliographical-data|dariah.eu|

All data existing in the in-file will be reproduced in the enriched out-file. This program can be used to both archive HTML and add data about the archiving process to an existing dataset with many headers and metadata attached to a URL.

## Output
The program `archive-html` generates two types of files. 

1. First, it produces an enriched CSV, which rewrites all the existing data from the in-file and adds data about the archived HTML. In the case of a simple in-file with a raw URL (https://medialab.sciencespo.fr/activites/epo/), the out-file would look like the following:

|normalized_url|domain|archive_subdirectory|archive_timestamp|
|--|--|--|--|
|medialab.sciencespo.fr/activites/epo|medialab.sciencespo.fr|8b058b21fea0cd4d36368998dc1b18a5|2022-11-18 14:53:44.844199|

2. Second, the program produces sub-directories for each URL succesfully scraped and archived. For example, if the user gave the option `--archive ./archive/` in the command, line, the HTML of the URL https://medialab.sciencespo.fr/activites/epo/ would be stored in the directory `./archive/8b058b21fea0cd4d36368998dc1b18a5/`

### *wish-list*:
3. *We would like to also resolve URLs discovered in the scraped HTML and save them to a CSV in the archived URL's sub-directory.*
4. *And we would like to download media files in the scraped HTML and save them to the archived URL's sub-directory.*


# Proposed Architecture

## Command Line
The program will accept 6 arguments.
- `--archive` (**required**, dir) : path to the main archive directory
- `--infile` (**required**, file) : path to the incoming CSV file
- `--urls` (**required**, str) : name of column containing the URLs to be processed; if normalized URLs are in the dataset this should point to the column of the normalized URLs
- `--domains` (*optional*, str) : name of column of the domain names, if present
- `-n` (*optional*, bool) : True if the given URLs are already normalized
- `--outfile` (*optional*, str) : path to the enriched CSV the program yields

```mermaid
flowchart TB
    CLI -->|"--archive"| archive[(archive)]
    CLI -->|"--infile"| infile[/in-file/]
    CLI -->|"--urls"| header1(URL col. header)
    CLI -->|"--domains"| header2(domains col. header)
    CLI --o|"-n"| id[normalized/\nnot normalized]
    CLI -->|"--outfile"| outfile[outfile]
```

## Parse CLI Arguments
As shown in the decision tree below, the program parses the CLI arguments to determine how it will process the incoming data file.

Returns:
- `archive_path` : path to directory
- `infile_path` : path to incoming data file
- `infile_fieldnames` : list of headers in file
- `enriched_fieldnames` : list of headers to be added to `infile_fieldnames` ("domain_col" and/or "normalized_url_col")
- `url_col` : string of key for the column containing URLs in file when read as `csv.DictReader` object
- `domain_col` string of key for the column containing domain names in file when read as `csv.DictReader` object (set to "domain_col" when the in-file did not have domain names)
- `normalized_url_col` : string of key for the column containing normalized_urls in file when read as `csv.DictReader` object (the value of `nonrmalized_url_col` will be the same as `url_col` if the URLs are already normalized)

When parsing the rows in the data file, the program will call columns using strings stored in the variables `url_col`, `domain_col`, and `normalized_url_col`.

```mermaid
flowchart TB

subgraph Legend
    yesno{Yes/True\nor No/False\nDecision}
    style yesno fill:#ffff00
    return[/Returned Data/]
    style return fill:#8000fe
    process[Process]
    cliOption(CLI Argument)
end

    archiveOption("--archive") --> archiveDecision{directory\nexists}
    style archiveDecision fill:#ffff00
    archiveDecision-->|no| noArchive[error]
    style noArchive fill:#ff0000
    archiveDecision -->|yes| yesArchive[continue]
    style yesArchive fill:#00ff00
    yesArchive --> archivePath[/archive_path/]
    style archivePath fill:#8000fe
    
    yesArchive -->infileOption("--in-file")
    infileOption --> infileQuestion{file\nexists}
    infileQuestion-->|no| noInfile[error]
    infileQuestion -->|yes| yesInfile[continue]
    yesInfile --> infilePath[/infile_path/]
    style infilePath fill:#8000fe
    style noInfile fill:#ff0000
    style yesInfile fill:#00ff00
    style infileQuestion fill:#ffff00

    yesInfile -->headersDecision{has\nheaders}
    style headersDecision fill:#ffff00
    headersDecision -->|no| noHeader[error]
    style noHeader fill:#ff0000
    headersDecision -->|yes| yesHeaders[continue]
    yesHeaders --> parseHeaders[parse all\nheaders]
    style yesHeaders fill:#00ff00

    parseHeaders --> fieldnames[/infile_fieldnames/]
    style fieldnames fill:#8000fe

    parseHeaders --> urlColDecision{--urls in\ninfile_fieldnames}
    style urlColDecision fill:#ffff00
    urlColDecision -->|no| noURLCol[error]
    style noURLCol fill:#ff0000
    urlColDecision -->|yes| yesURLCol[continue]
    style yesURLCol fill:#00ff00
    yesURLCol --> setURLCol[url_col = --urls]
    setURLCol --> returnURLCol[/url_col/]
    style returnURLCol fill:#8000fe

    yesURLCol --> normalizedOptionDecision{-n \nboolean}
    style normalizedOptionDecision fill:#ffff00
    normalizedOptionDecision -->|True| firstURLDecision{first URL in\ncolumn --urls\nis normalized}
    style firstURLDecision fill:#ffff00
    normalizedOptionDecision -->|False| addNormalizedURLCol["enriched_fieldnames + ['normalized_url']"]
    firstURLDecision -->|yes| yesNormalizedURL[normalized_url_col = url_col]
    yesNormalizedURL --> returnYesNormalizedURL[/normalized_url_col/]
    style returnYesNormalizedURL fill:#8000fe
    firstURLDecision -->|no| addNormalizedURLCol
    addNormalizedURLCol --> setNoNormalizedURLCol["normalized_url_col = 'normalized_url'"]
    setNoNormalizedURLCol --> returnNoNormalizedURL[/normalized_url_col/]
    style returnNoNormalizedURL fill:#8000fe

    makeEmptyEnrichedFieldnames["enriched_fieldnames.extend(infile_fieldnames)"]
    fieldnames --> makeEmptyEnrichedFieldnames
    emptyEnrichedFieldnames[/enriched_fieldnames/]
    makeEmptyEnrichedFieldnames --> emptyEnrichedFieldnames
    emptyEnrichedFieldnames --> addNormalizedURLCol
    emptyEnrichedFieldnames --> addDomainCol
    addNormalizedURLCol --> returnEnrichedFieldnames[/enriched_fieldnames/]
    addDomainCol --> returnEnrichedFieldnames[/enriched_fieldnames/]
    style returnEnrichedFieldnames fill:#8000fe

    yesURLCol --> domainsDecision{--domains\noption}
    style domainsDecision fill:#ffff00
    domainsDecision -->|False| addDomainCol["enriched_fieldnames + ['domain']"]
    domainsDecision -->|True| domainsOption{--domains in\ninfile_fieldnames}
    style domainsOption fill:#ffff00
    domainsOption -->|no| domainOptionError[error]
    style domainOptionError fill:#ff0000
    domainsOption -->|yes| setDomainCol[domain_col = --domains]
    setDomainCol --> returnSetDomainCol[/domain_col/]
    style returnSetDomainCol fill:#8000fe
    addDomainCol --> setNoDomainCol["domain_col = 'domain'"]
    setNoDomainCol --> returnNoDomainCol[/domain_col/]
    style returnNoDomainCol fill:#8000fe
```

```python
class Parameters(object):
    """Realizes the decision tree in the diagram above,
        and returns the following parameters. Those that
        are important to (used by) later functions are 
        marked with a comment.
    """
    def __init__(self, archive, infile, urls, domains, n)
        self.archive_path = archive  # IMPORTANT
        self.infile = infile  # IMPORTANT
        self.url_col = urls # IMPORTANT
        self.self.domain_col = domains  # IMPORTANT
        self.normalized = n
        self.normalized_url_col = None  # IMPORTANT
        self.infile_fieldnames = []
        self.enriched_fieldnames = []  # IMPORTANT

```

## Parse In-File

Next, the program parses the entire incoming CSV file, row by row, both enriching the row's URL as well as fetching and archiving its HTML.

```mermaid
flowchart TD
subgraph Step 1. Parse CLI
args[/args/]
end
subgraph In-File
    args -->|infile_path| reader1
    reader1[(reader)] --> rowBefore[/"row (dict)"/]
end
subgraph Out-File
    args -->|enriched_fieldnames,\noutfile_path| writer[(writer)]
    rowAfter --> writeRow[write row]
    writeRow --> writer
end
subgraph Step 2. Enrich
    rowBefore --> enrichment[enrich URL] --> rowMiddle[/"row (dict)"/]
    ural(URAL) --> enrichment
    args -->|url_col,\nnormalized_url_col\ndomain_col| enrichment
    style ural fill:#0000fe
end
subgraph Step 3. Archive
    rowMiddle --> archive1[archive URL] --> rowAfter[/"row (dict)"/]
    minet(Minet) --> archive1
    args -->|normalized_url_col| archive1
    style minet fill:#0000fe
end
subgraph Legend
    iterable[(iterable)]
    object[/object/]
    tools(external\ntools)
    style tools fill:#0000fe
    process[process]
end
```
---
### Enrichment steps:

1. If there's no data in the column known under the variable `normalized_url_col`, the program normalizes the URL in `row[url_col]`.
2. If there's no data in the column known under the variable `domain_col`, the program gets the domain name from the normalized URL.
3. The program returns a (potentially) modified `row` dictionary object.

---
### Archiving steps:

3. The program creates a hash of the normalized URL.
4. It then searches in the archive directory for any sub-directories bearing that name.
5. If there are no subdirectories with that name, the program attempts to call the URL with the concatenation of `https://` and `normalized_url`.
4. If the call is unsuccessful, the problematic URL is logged along with its domain name, and the program moves onto the next URL.
5. If the call is successful, the program attempts to scrape the HTML from the page and write the response to a file in the subdirectory.
6. The current time is recorded and given to the field `archive_timestamp`.
7. The hash of the normalized URL is given to the field `archive_subdirectory`.

```mermaid
flowchart TD
    pull["pull normalized URL from row[args.normalized_url_col]"] --> hash_url
    hash_url[hash the normalized URL] --> checkDir[check the archive for a subdirectory with that hashed name]
    checkDir --> scrape[scrape HTML from the normalized URL]
    scrape --> makeDir[make a subdirectory with the name of the hashed URL]
    makeDir --> write[write the scraped HTML to a file in the subdirectory]
    write --> timestamp[update the row object with a timestamp]
    timestamp --> hash_name[update the row object with the subdirectory name]
```

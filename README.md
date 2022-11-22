# Archive HTML

The program `archive-html` takes a list (CSV file) of URLs and enriches each row with the following data:

1. **metadata about the URL**
    - normalized version of the URL
    - domain name
2. **data about the archived HTML**:
    - name of a sub-directory which contains a file of the page's scraped HTML
    - timestamp of when the HTML was scraped and archived

# Proposed Data Structure

From the Command Line (CLI), the user provides (1) a path to the archive which will store the scraped HTML, (2) a path to the in-file which contains the URLs as well as (3) the header name of that mandatory column.

```mermaid
flowchart LR
    start[CLI] --> archive[(archive)]
    start[CLI] --> cli2[/in-file/]
    archive[(archive)] --- sub[sub-directory] --- html[/html/]
    cli2[/in-file/] -->|hash of normalized URL| sub[sub-directory]
    cli2[/in-file/] -->|scraped URL| html[/html/]
    cli2[/in-file/] --> outfile[/out-file/]
```

The name of each sub-directory in the archive is a hash of the normalized URL, which guarantees that the archive does not contain duplicate archives of the same URL.
```mermaid
flowchart TB
    subgraph archive architecture
    id1[(archive)] --- id2[url_hash1]
    id1[(archive)] --- id3[url_hash2]
    id2[url_hash1] --- id4[/html/]
    id3[url_hash2] --- id5[/html/]
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

1. First, it produces an enriched CSV, which rewrites all the existing data from the in-file and adds data about the archived HTML. In the case of a simple in-file with a raw URL (https://medialab.sciencespo.fr/activites/epo/) and its ID (tcbeehb0040dumd), the out-file would look like the following:

|normalized_url|domain|archive_subdirectory|archive_timestamp|
|--|--|--|--|
|medialab.sciencespo.fr/activites/epo|medialab.sciencespo.fr|8b058b21fea0cd4d36368998dc1b18a5|2022-11-18 14:53:44.844199|

2. Second, the program produces sub-directories for each URL succesfully scraped and archived. For example, if the user gave the option `--archive ./archive/` in the command, line, the HTML of the URL https://medialab.sciencespo.fr/activites/epo/ would be stored in the directory `./archive/8b058b21fea0cd4d36368998dc1b18a5/`

### *wish-list*:
3. *We would like to also resolve URLs discovered in the scraped HTML and save them to a CSV in the archived URL's sub-directory.*
4. *And we would like to download media files in the scraped HTML and save them to the archived URL's sub-directory.*


# Proposed Architecture

## Command Line
The program will accept 5 arguments.
- `--archive` (**required**, dir) : path to the main archive directory
- `--infile` (**required**, file) : path to the in-file CSV
- `--urls` (**required**, str) : name of column containing the URLs to be processed; if normalized URLs are in the dataset this should point to the column of the normalized URLs
- `--domains` (*optional*, str) : name of column of the domain names, if present
- `-n` (*optional*, bool) : True if the given URLs are already normalized

```mermaid
flowchart TB
    CLI -->|"--archive"| archive[(archive)]
    CLI -->|"--infile"| infile[/in-file/]
    CLI -->|"--urls"| header1(URL col. header)
    CLI -->|"--domains"| header2(domains col. header)
    CLI --o|"-n"| id[normalized/\nnot normalized]
```

## Parse CLI Arguments
As shown in the decision tree below, the program parses the CLI arguments to determine how it will process the incoming data file.

Returns:
- `archive_path` : path to directory
- `infile_path` : path to file
- `infile_fieldnames` : list of headers in file
- `enriched_fieldnames` : list of headers to be added to `infile_fieldnames` ("domain_col" and/or "normalized_url_col")
- `url_col` : string of key for the column containing URLs in file when read as `csv.DictReader` object
- `domain_col` string of key for the column containing domain names in file when read as `csv.DictReader` object (set to "domain_col" when the in-file did not have domain names)
- `normalized_url_col` : string of key for the column containing normalized_urls in file when read as `csv.DictReader` object (the value of `nonrmalized_url_col` will be the same as `url_col` if the URLs are already normalized)

When parsing the dataset, the program will call columns using strings stored in the variables `url_col`, `domain_col`, and `normalized_url_col`. The column name for the normalized URLs will be the same as that entered via the CLI in the option `--urls` (stored in `url_col`) if the URLs in the dataset are already normalized. If the URLs are not normalized, the program will create a column `normalized_url_col` and, while parsing the CSV row by row, every time it discovers that a cell in the column `normalized_url_col` is empty, it will create a normalized version of the URL in column `url_col` and write it into the column `normalized_url_col`. The same sort of enrichnment will be done in the created column `domain_col` if the dataset does not already have domain names.

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
    """Realizes the decision tree in the diagram above"""
    def __init__(self, archive, infile, urls, domains, n)
    self.archive_path = archive  # IMPORTANT
    self.infile = infile  # IMPORTANT
    self.url_col = urls
    self.self.domain_col = domains  # IMPORTANT
    self.normalized = n
    self.normalized_url_col = None  # IMPORTANT
    self.infile_fieldnames = []
    self.enriched_fieldnames = []  # IMPORTANT

```

## Parse In-File

Next, the program parses the entire incoming CSV file, row by row, both enriching the row's URL as well as fetching and archiving its HTML.

Enrichment steps:

1. If there's no data in the column known under the variable `normalized_url_col`, the program normalizes the URL in `row[url_col]`.
2. If there's no data in the column known under the variable `domain_col`, the program gets the domain name from the normalized URL.
3. The program returns a (potentially) modified `row` dictionary object.

Parameters
- `row` (dict) from `csv.DictReader`
- `normalized_url_col` (str)
- `url_col` (str)
- `domain` (str)

Return:
- `row` (dict)

```mermaid
flowchart LR
subgraph Row
row[/row/]
end
subgraph Domain
    domain_col[/domain_col/]
    domain_col -->domains{"row.get(domain_col)"}
    row --> domains
    style domains fill:#ffff00
    domains --o|string| yesDom["row[domain_col]"]
    domains -->|None| noDom["get_domain(normalized_url)"]
    normalized_url --> noDom
    noDom -->|update row| writeDom["row[domain_col]=domain"]
    writeDom --> returnRow[/row/]
    style returnRow fill:#8000fe
    
end
subgraph Normalized URL
    normalized_col[/normalized_url_col/]
    url_col[/url_col/]
    row --> normalized
    normalized_col --> normalized{"row.get(normalized_url_col)"}
    style normalized fill:#ffff00
    normalized -->|string| normUrl["row[normalized_url_col]"]
    normalized -->|None| notNormUrl["normalize_url(row[url_col])"]
    url_col --> notNormUrl
    normalized_url[/normalized_url/]
    notNormUrl -->|update row| writeNorm["row[normalized_url_col]=normalized_url"]
    writeNorm --> returnRow
    style returnRow fill:#8000fe
    normUrl --> normalized_url
    notNormUrl --> normalized_url
end
```

Archiving steps:

3. The program creates a hash of the normalized URL.
4. It then searches in the archive directory for any sub-directories bearing that name.
5. If there are no subdirectories with that name, the program attempts to call the URL with the concatenation of `https://` and `normalized_url`.
4. If the call is unsuccessful, the problematic URL is logged along with its domain name, and the program moves onto the next URL.
5. If the call is successful, the program attempts to scrape the HTML from the page and write the response to a file in the subdirectory.
6. The current time is recorded and given to the field `archive_timestamp`.
7. The hash of the normalized URL is given to the field `archive_subdirectory`.

Parameters:
- `row` (dict) in `csv.DictReader`
- `archive` (str)
- `normalized_url_col` (str)

```mermaid
flowchart TD
    hash_url[hash normalized URL] --> checkDir[check archive for hash]
    checkDir --> scrape[scrape HTML]
    scrape --> makeDir[make a subdirectory with name of hash]
    makeDir --> write[write HTML to file in subdirectory]
    write --> timestamp[write timestamp to enriched CSV]
    timestamp --> hash_name[write subdirectory name to enriched CSV]
```
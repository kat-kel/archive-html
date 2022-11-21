# Archive HTML

The program `archive-html` takes a list (CSV file) of URLs and enriches each row with the following data:

1. **metadata about the URL**
    - normalized version of the URL
    - domain name
2. **data about the archived HTML**:
    - name of a sub-directory which contains a file of the page's scraped HTML
    - timestamp of when the HTML was scraped and archived

# Proposed Data Structure

From the Command Line (CLI), the user provides (1) a path to the archive which will store the scraped HTML, (2) a path to the in-file which contains the URLs and their IDs, as well as the header names of the two mandatory columns: (3) IDs and (4) URLs.

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
The in-file must be a CSV with headers and have at least the following 2 columns: ID and URL.

### **Minimum Requirements of the In-File:**
|id|url|
|--|--|
|tcbeehb0040dumd|https://medialab.sciencespo.fr/activites/epo/|
|qvsfbq6yfkwgtm3|https://twitter.com/bu_unistra/status/1592121602480955392|
|2gm269lmsapwn49|https://www.dariah.eu/2022/10/10/mutual-learning-workshop-for-improving-cultural-heritage-bibliographical-data/|


### **Maximum Elements of the In-File Taken into Account**
The in-file CSV may contain many other columns and metadata, but the program `archive-html` will only parse the following data:
|id|normalized_url|domain|
|--|--|--|
|tcbeehb0040dumd|medialab.sciencespo.fr/activites/epo|medialab.sciencespo.fr|
|qvsfbq6yfkwgtm3|twitter.com/bu_unistra/status/1592121602480955392|huma-num.fr|
|2gm269lmsapwn49|dariah.eu/2022/10/10/mutual-learning-workshop-for-improving-cultural-heritage-bibliographical-data|dariah.eu|

All data existing in the in-file will be reproduced in the enriched out-file. This program can be used to both archive HTML and add data about the archiving process to an existing dataset with many headers and metadata attached to a URL.

## Output
The program `archive-html` generates two types of files. 

1. First, it produces an enriched CSV, which rewrites all the existing data from the in-file and adds data about the archived HTML. In the case of a simple in-file with a raw URL (https://medialab.sciencespo.fr/activites/epo/) and its ID (tcbeehb0040dumd), the out-file would look like the following:

|id|normalized_url|domain|archive_subdirectory|archive_timestamp|
|--|--|--|--|--|
|tcbeehb0040dumd|medialab.sciencespo.fr/activites/epo|medialab.sciencespo.fr|8b058b21fea0cd4d36368998dc1b18a5|2022-11-18 14:53:44.844199|

2. Second, the program produces sub-directories for each URL succesfully scraped and archived. For example, if the user gave the option `--archive ./archive/` in the command, line, the HTML of the URL https://medialab.sciencespo.fr/activites/epo/ would be stored in the directory `./archive/8b058b21fea0cd4d36368998dc1b18a5/`

### *wish-list*:
3. *We would like to also resolve URLs discovered in the scraped HTML and save them to a CSV in the archived URL's sub-directory.*
4. *And we would like to download media files in the scraped HTML and save them to the archived URL's sub-directory.*


# Proposed Architecture

## Command Line
The program will except 6 arguments.
- `--archive` (**required**, dir) : path to the main archive directory
- `--infile` (**required**, file) : path to the in-file CSV
- `--urls` (**required**, str) : name of column containing the URLs to be processed; if normalized URLs are in the dataset this should point to the column of the normalized URLs
- `--ids` (**required**, str) : name of column of the URLs' IDs
- `--domains` (*optional*, str) : name of column of the domain names, if present
- `-n` (*optional*, bool) : True if the given URLs are already normalized

```mermaid
flowchart TB
    CLI -->|"--archive"| archive[(archive)]
    CLI -->|"--infile"| infile[/in-file/]
    CLI -->|"--urls"| header1(URL col. header)
    CLI -->|"--ids"| header3(ID col. header)
    CLI -->|"--domains"| header2(domains col. header)
    CLI --o|"-n"| id[normalized/\nnot normalized]
```

## Parse CLI Arguments
As shown in the decision tree below, the program parses the CLI arguments to determine how it will process the incoming data file. The initial parsing of the CLI arguments as well as a peek at the headers and first row of data confirms the following information:

- all the headers of the incoming CSV file : `infile_fieldnames` (list)
- the header of the column containing the IDs: `id_col` (string)
- the header of the column containing the URLs : `url_col` (string)
- whether that column's URLs are normalized or not : `normalized` (boolean)
- if present, the header of the column containing the domain names: `domain_col` (string)

To the list of headers in `infile_fieldnames`, the following column headers are added if certain conditions are met:
- if the URLs are not normalized, the header name `normalized_url_col` is added to list `enriched_fieldnames`
- if a column containing domain names is not present, the header name `domain_col` is added to the list `enriched_fieldnames`

```mermaid
flowchart TB
    A("--archive") --> Aq{directory\nexists}
    Aq-->|no| An[error]
    Aq -->|yes| Ay[continue]
    style An fill:#ff0000
    style Ay fill:#00ff00
    style Aq fill:#ffff00
    
    Ay -->F("--in-file")
    F --> Fq{file\nexists}
    Fq-->|no| Fn[error]
    Fq -->|yes| Fy[continue]
    style Fn fill:#ff0000
    style Fy fill:#00ff00
    style Fq fill:#ffff00
    
    Fy -->Hq{has\nheaders}
    Hq -->|no| Hn[error]
    Hq -->|yes| Hy[continue]
    Hy --> p[parse all\nheaders]
    p --> fieldnames[/infile_fieldnames/]
    style Hn fill:#ff0000
    style Hy fill:#00ff00
    style Hq fill:#ffff00

    fieldnames --> IDq{--ids in fieldnames}
    IDq -->|no| IDno[error]
    IDq -->|yes| IDyes[continue]
    style IDno fill:#ff0000
    style IDq fill:#ffff00
    style IDyes fill:#00ff00
    
    IDyes --> URL_header{--urls in\nfieldnames}
    IDyes --> IDdata[/id_col = --ids/]
    
    URL_header -->|yes| URLyes[continue]
    URLyes --> URLdata[/url_col = --urls/]
    URL_header -->|no| URLno[error]
    style URLno fill:#ff0000
    style URLyes fill:#00ff00
    style URL_header fill:#ffff00

    URLyes --> Norm{-n \nboolean}
    style Norm fill:#ffff00
    Norm -->|False| Normno[/normalized = False/]
    enriched["enriched_fieldnames = []"]
    Norm -->|True| Normyes{first URL in\ncolumn --urls\nis normalized}
    style Normyes fill:#ffff00
    Normyes -->|no| Normno
    Normyes -->|yes| Nyes[/normalized = True/]
    
    enriched --> makeNorm
    Normno --> makeNorm["enriched_fieldnames + ['normalized_url_col']"]
    
    URLyes -->Dom{--domains\noption}
    style Dom fill:#ffff00

    Dom -->|False| makeDom["enriched_fieldnames + ['domain_col']"]

    Dom -->|True| Dom_header{--domains in\nfieldnames}
    Dom_header -->|no| makeDom
    Dom_header -->|yes| Domyes[/domain_col = --domains/]
    style Dom_header fill:#ffff00

    enriched --> makeDom
```

## Parse In-File

Next, the program parses the entire incoming CSV file, row by row, both enriching the row's URL as well as fetching and archiving its HTML.

Enrichment steps:

1. If `normalized` is False, the program normalizes the URL in `row[url_col]`.
2. If there's no data in the column known under the variable `domain_col`, the program gets the domain name from the normalized URL.
3. The program also writes these data to the relevant fields if they did not already exist in the input dataset.

```mermaid
flowchart LR
subgraph Normalized URL
    normalized{normalized}
    style normalized fill:#ffff00
    normalized -->|True| normUrl["row[url_col]"]
    normalized -->|False| notNormUrl["normalize_url(row[url_col])"]
    normalized_url[/normalized_url/]
    notNormUrl -->|update row| writeNorm["row[normalized_url]=normalized_url"]
    normUrl --> normalized_url
    notNormUrl --> normalized_url
end
subgraph Domain
    domain_col[/domain_col/]
    domain_col -->domains{"row[domain_col]"}
    style domains fill:#ffff00
    domains -->|string| yesDom["row[domain_col]"]
    yesDom --> domain_name
    domain_name[/domain/]
    domains -->|None| noDom["get_domain(normalized_url)"]
    normalized_url --> noDom
    noDom -->|update row| writeDom["row[domain_col]=domain"]
    noDom --> domain_name
    
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


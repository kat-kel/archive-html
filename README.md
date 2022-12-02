# Archive HTML

The program `archive-html` takes a list (CSV file) of URLs and enriches each row with the following data:

- hash of the normalized URL, which is (a) the file name of the HTML fetched with minet and (b) identifier for the archived page's log and paths files.
- timestamp of when minet fetched the HTML
- timestamp of when the entire page was logged in the archive 

# Workflow

## Step 1. Minet Fetch & Log Fetch Timestamp
```shell
$ python cli.py fetch PATH/TO/DATA.csv
```
1. Hash the URL with the same `md5` hash that minet uses and add that hash to the data file.
2. Use minet to fetch the HTML, which minet stores in a file named for the hashed URL.

## Step 2. WGET Archive
```shell
$ script-wget.sh PATH/TO/DATA.csv
```
1. Parse the data file's `url` and `url_hash` fields.
2. Register the current time and call the `wget` command to (a) archive the `url` and (b) write the `wget` log to file `log_<url_hash>`.

    Example of data:

    ---

    |url|url_hash|
    |--|--|
    |`https://medialab.sciencespo.fr/`|`61c2b0685daf5dac7e777c37a00a0844`|

    Example of result:
    > `script-wget.sh` would (a) archive URL "`https://medialab.sciencespo.fr/`" and (b) save the `wget` log to "`log_61c2b0685daf5dac7e777c37a00a0844`".

    ---
3. Append the time that `wget` was called to the log file.

## Step 3. Log WGET Archive Timestamp
```shell
$ python cli.py archive-timestamp PATH/TO/DATA.csv ARCHIVE/DIRECTORY/
```
1. Iterate through files in `ARCHIVE/DIRECTORY` and extract file paths for all logs in the archive.
2. Extract the timestamp from the `wget` log and add it to that column `archive_timestamp` column in the CSV.


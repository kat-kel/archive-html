import csv
import click
from exceptions import FileFormatError, CSVHeaderError
from ural import normalize_url as ural_normalize_url
import os


yellow = "\033[1;33m\n"
reset = "\033[0m"


class Arguments(object):
    """Verifies that all the CLI arguments are valid and returns parameters

    Parameters:
        archive (str): value of --archive [required], path to the archive
        infile (str): value of --infile [required], path to the data file
        urls (str): value of --urls [required], name of the URLs column
        domains (str): value of --domains [optional], name of the domains column
        n (bool): value of --n [optional], declaration of whether the URLs are normalized
    
    Returns:
        Arguments().archive_path (str): path to the archive
        Arguments().infile_path (str): path to the data file
        Arguments().url_col (str): name of the URLs column
        Arguments().normalized (bool): whether the URLs are normalized  *no longer important*
        Arguments().normalized_url_col (str): either the name of the column in the data file contains normalized URLs 
            or the name of the column in the out-file that will contain normalized URLs
        Arguments().infile_fieldnames (list): list of column headers in data file *no longer important*
        Arguments().enriched_fieldnames (list): list of column headers for out-file
    """
    def __init__(self, archive, infile, urls, domains, n):
        self.archive_path = archive
        self.infile_path = infile
        self.url_col = urls
        self.domain_col = domains
        self.normalized = n
        self.normalized_url_col = None
        self.infile_fieldnames = []
        self.enriched_fieldnames = []

        # Verify that the archive is a directory
        if not os.path.isdir(self.archive_path):
            raise NotADirectoryError(f"{yellow}{self.archive_path} is not a directory.{reset}")

        # Verify that the infile is a file
        if not os.path.isfile(self.infile_path):
            raise FileNotFoundError(f"{yellow}{self.infile_path} is not a file.{reset}")

        with open(self.infile_path) as f:
            # Verify that the CSV can be opened with headers
            try:
                reader = csv.DictReader(f)
                self.infile_fieldnames.extend(reader.fieldnames)
            except:
                raise FileFormatError(f"{yellow}Unable to read {self.infile_path} as CSV file.{reset}")

            # Set up a row of data to test
            test_row = next(reader)

            # Verify that the given name of the URLs column is in the CSV
            if not test_row.get(self.url_col):
                raise CSVHeaderError(column=self.url_col)
            
            # If declared to be normalized, verify that the URLs column contains normalized URLs
            if not self.normalized or test_row[self.url_col] != ural_normalize_url(test_row[self.url_col]):
                self.enriched_fieldnames.append("normalized_url")
                self.normalized_url_col = "normalized_url"
            else:
                self.normalized_url_col = self.url_col

            # If given, verify that the name of the domains column is in the CSV
            if self.domain_col and not test_row.get(self.domain_col):
                raise CSVHeaderError(column=self.domain_col)

            if not self.domain_col:
                self.enriched_fieldnames.append("domain")
                self.domain_col = "domain"
            
            self.enriched_fieldnames.extend(self.infile_fieldnames)


@click.command()
@click.option("--archive", type=click.Path(exists=True), required=True, help="Path to archive in which subdirectories of archived HTML will be stored.")
@click.option("--infile", type=click.Path(exists=True), required=True, help="Path to the CSV file containing the URLs to be processed.")
@click.option("--urls", type=str, required=True, help="Header of column containing URLs.")
@click.option("--domains", type=str, required=False, help="Header of column containing domain names.")
@click.option("-n", type=bool, is_flag=True, default=False, required=False, help="Flag indicating the URLs are already normalized.")
def cli(archive, infile, urls, domains, n):
    args = Arguments(archive, infile, urls, domains, n)

if __name__ == "__main__":
    cli()

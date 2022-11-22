yellow = "\033[1;33m\n"
reset = "\033[0m"


class FileFormatError(Exception):
    def __init__(self, m):
        self.message = m


class CSVHeaderError(Exception):
    def __init__(self, column):
        self.col = column
    
    def __str__(self) -> str:
        return f"{yellow}Column '{self.col}' not found in CSV file.{reset}"

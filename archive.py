from pywebcopy import save_web_page


def archive_row(args, row):
    # clean URL to fetch
    # name subdirectory (based on hash of URL)
    # define path to subdirectory
    # name sub-subdirectory
    # give 3 arguments to pywebcopy's command save_web_page()

    # update CSV with subdirectory name and timestamp
    return row


def copy_page(url, directory, name):
    save_web_page(
        url=url,
        project_folder=directory,
        project_name=name,
        bypass_robots=True,
        debug=True,
        open_in_browser=True,
        delay=None,
        threaded=False,
    )

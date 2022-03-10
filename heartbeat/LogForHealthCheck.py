import logging
from systemd.journal import JournalHandler

def logger() -> logging:
    # get an instance of the logger object this module will use
    logger = logging.getLogger(__name__)

    # instantiate the JournaldLogHandler to hook into systemd
    journald_handler = JournalHandler()

    # set a formatter to include the level name
    journald_handler.setFormatter(logging.Formatter(
        '[%(levelname)s] %(message)s'
    ))

    # add the journald handler to the current logger
    logger.addHandler(journald_handler)

    # optionally set the logging level
    logger.setLevel(logging.WARNING)
    return logger

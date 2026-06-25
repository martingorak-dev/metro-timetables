import camelot
import sys

pdf = sys.argv[1]
xlsx = sys.argv[2]

print("Reading PDF:", pdf)
tables = camelot.read_pdf(pdf, pages="all")

print("Exporting to:", xlsx)
tables.export(xlsx, f="excel")

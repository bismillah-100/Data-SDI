import pandas as pd
import sys
from reportlab.lib.pagesizes import landscape
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle
from reportlab.lib.units import inch

def convert_csv_to_pdf(csv_file, pdf_file):
    df = pd.read_csv(csv_file, sep=";")
    df = df.fillna("")  # Ganti data kosong
    df = df.astype(str)  # Ubah semua data menjadi string

    headers = list(df.columns)
    data = df.values.tolist()
    full_data = [headers] + data

    # Atur lebar kolom
    min_width = 0.01 * inch
    padding = 0.5 * inch  # Padding untuk setiap kolom

    # Hitung lebar kolom berdasarkan panjang maksimum string di setiap kolom
    col_widths = []
    for i in range(len(full_data[0])):
        max_length = max(len(str(row[i])) for row in full_data)  # Panjang maksimum dari kolom i
        col_width = max(min_width, max_length * 0.07 * inch + padding)  # Tambahkan padding
        col_widths.append(col_width)

    # Ukuran halaman
    page_height = 11 * inch
    custom_page_size = (sum(col_widths) + 1 * inch, page_height)

    pdf = SimpleDocTemplate(pdf_file, pagesize=custom_page_size,
                            topMargin=10, bottomMargin=10, leftMargin=10, rightMargin=10)

    table = Table(full_data, colWidths=col_widths, repeatRows=1)
    
    style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#4c7e4c")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),  # Gunakan font monospace
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 2),  # Padding lebih kecil
        ('BACKGROUND', (0, 1), (-1, -1), colors.whitesmoke),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
    ])
    table.setStyle(style)

    elements = [table]
    pdf.build(elements)
    print(f"File PDF berhasil disimpan di: {pdf_file}")

if __name__ == "__main__":
    csv_file = sys.argv[1]
    pdf_file = csv_file.replace(".csv", ".pdf")
    convert_csv_to_pdf(csv_file, pdf_file)

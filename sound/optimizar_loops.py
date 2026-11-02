import os
import struct
import subprocess
import sys

def extraer_chunks_de_loop(ruta_wav):
    chunks_loop = []
    tiene_loop = False

    try:
        with open(ruta_wav, 'rb') as f:
            header = f.read(12)
            if len(header) < 12 or header[:4] != b'RIFF' or header[8:12] != b'WAVE':
                return False, []

            while True:
                chunk_header = f.read(8)
                if len(chunk_header) < 8:
                    break
                
                chunk_id, chunk_size = struct.unpack('<4sI', chunk_header)
                chunk_data = f.read(chunk_size)

                if chunk_id == b'cue ' and len(chunk_data) >= 4:
                    num_cues = struct.unpack('<I', chunk_data[:4])[0]
                    if num_cues > 0:
                        tiene_loop = True
                    chunks_loop.append((chunk_id, chunk_data))

                elif chunk_id == b'smpl' and len(chunk_data) >= 36:
                    num_loops = struct.unpack('<I', chunk_data[28:32])[0]
                    if num_loops > 0:
                        tiene_loop = True
                    chunks_loop.append((chunk_id, chunk_data))

                elif chunk_id in (b'LIST', b'note', b'labl', b'ltxt'):
                    chunks_loop.append((chunk_id, chunk_data))

                if chunk_size % 2 != 0:
                    f.seek(1, os.SEEK_CUR)

        return tiene_loop, chunks_loop
    except Exception as e:
        print(f"[ERROR] Lectura fallida en {ruta_wav}: {e}")
        return False, []

def inyectar_chunks(ruta_wav, chunks_a_insertar):
    if not chunks_a_insertar:
        return

    with open(ruta_wav, 'r+b') as f:
        f.seek(0, os.SEEK_END)
        for chunk_id, chunk_data in chunks_a_insertar:
            f.write(struct.pack('<4sI', chunk_id, len(chunk_data)))
            f.write(chunk_data)
            if len(chunk_data) % 2 != 0:
                f.write(b'\x00')

        tamano_total = f.tell()
        f.seek(4, os.SEEK_SET)
        f.write(struct.pack('<I', tamano_total - 8))

def cumple_metrica_exacta(ruta_wav):
    """Verifica si ya es Mono, 44100Hz y 16-bit."""
    try:
        cmd = [
            'ffprobe', '-v', 'error',
            '-select_streams', 'a:0',
            '-show_entries', 'stream=channels,sample_rate,bits_per_raw_sample',
            '-of', 'csv=p=0:s=,',
            ruta_wav
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        datos = res.stdout.strip().split(',')
        
        # datos suele ser [sample_rate, channels, bits] -> ej: "44100,1,16"
        if len(datos) >= 2:
            sample_rate = datos[0].strip()
            channels = datos[1].strip()
            bits = datos[2].strip() if len(datos) > 2 and datos[2].strip() else "16"
            
            if sample_rate == '44100' and channels == '1' and (bits == '16' or bits == 'N/A'):
                return True
        return False
    except Exception:
        return False

def procesar_loops(directorio_raiz):
    total_optimizados = 0
    total_ya_optimos = 0
    total_sin_loop = 0

    print(f"Iniciando escaneo en: {directorio_raiz}\n")

    for raiz, _, archivos in os.walk(directorio_raiz):
        for archivo in archivos:
            if archivo.lower().endswith('.wav'):
                ruta_wav = os.path.join(raiz, archivo)
                rel_path = os.path.relpath(ruta_wav, directorio_raiz)
                
                tiene_loop, chunks = extraer_chunks_de_loop(ruta_wav)

                if not tiene_loop:
                    total_sin_loop += 1
                    continue

                if cumple_metrica_exacta(ruta_wav):
                    print(f"[IGNORADO - YA CUMPLE]  {rel_path}")
                    total_ya_optimos += 1
                    continue

                ruta_temporal = os.path.join(raiz, f"temp_{archivo}")
                print(f"[OPTIMIZANDO LOOP]     {rel_path}")

                cmd_ffmpeg = [
                    'ffmpeg', '-y', '-v', 'error',
                    '-i', ruta_wav,
                    '-vn',
                    '-ar', '44100',
                    '-ac', '1',
                    '-c:a', 'pcm_s16le',
                    ruta_temporal
                ]

                try:
                    subprocess.run(cmd_ffmpeg, check=True)
                    inyectar_chunks(ruta_temporal, chunks)
                    os.replace(ruta_temporal, ruta_wav)
                    total_optimizados += 1

                except subprocess.CalledProcessError:
                    print(f"[ERROR CONVERSIÓN]    {rel_path}")
                    if os.path.exists(ruta_temporal):
                        os.remove(ruta_temporal)
                except Exception as e:
                    print(f"[ERROR INYECCIÓN]     {rel_path}: {e}")
                    if os.path.exists(ruta_temporal):
                        os.remove(ruta_temporal)

    print("\n-------------------------------------------")
    print(f"Resumen del proceso:")
    print(f"- Optimizados y reemplazados: {total_optimizados}")
    print(f"- Ignorados (ya cumplían Mono 44.1kHz 16-bit): {total_ya_optimos}")
    print(f"- Ignorados (sin loop / one-shots): {total_sin_loop}")

if __name__ == "__main__":
    carpeta = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    procesar_loops(carpeta)
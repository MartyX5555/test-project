import os
import struct
import subprocess
import sys

def extraer_chunks_de_loop(ruta_wav):
    """
    Lee el archivo WAV y extrae todos los chunks de metadatos de bucle 
    (cue, smpl, labl, ltxt, note, etc.) para poder reinyectarlos luego.
    """
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

                # Detección de bucles en chunks típicos de Source / Sound Forge
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
                    # Chunks asociados a etiquetas de marcadores de loop
                    chunks_loop.append((chunk_id, chunk_data))

                # Alineación RIFF a 2 bytes
                if chunk_size % 2 != 0:
                    f.seek(1, os.SEEK_CUR)

        return tiene_loop, chunks_loop
    except Exception as e:
        print(f"[ERROR] Lectura fallida en {ruta_wav}: {e}")
        return False, []

def inyectar_chunks(ruta_wav, chunks_a_insertar):
    """
    Reinyecta los chunks de bucles extraídos al final del archivo WAV nuevo
    y recalcula el tamaño total del encabezado RIFF.
    """
    if not chunks_a_insertar:
        return

    with open(ruta_wav, 'r+b') as f:
        f.seek(0, os.SEEK_END)
        for chunk_id, chunk_data in chunks_a_insertar:
            # Escribir ID y tamaño del chunk
            f.write(struct.pack('<4sI', chunk_id, len(chunk_data)))
            f.write(chunk_data)
            # Relleno de byte si no es par
            if len(chunk_data) % 2 != 0:
                f.write(b'\x00')

        # Recalcular y actualizar el tamaño total RIFF (los primeros 4 bytes tras 'RIFF')
        tamano_total = f.tell()
        f.seek(4, os.SEEK_SET)
        f.write(struct.pack('<I', tamano_total - 8))

def es_ya_mono(ruta_wav):
    """Comprueba si el WAV ya está en Mono para evitar reprocesarlo."""
    try:
        cmd = [
            'ffprobe', '-v', 'error',
            '-select_streams', 'a:0',
            '-show_entries', 'stream=channels',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            ruta_wav
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return res.stdout.strip() == '1'
    except Exception:
        return False

def procesar_loops(directorio_raiz):
    total_optimizados = 0
    total_saltados = 0

    print(f"Buscando archivos con loop en: {directorio_raiz}\n")

    for raiz, _, archivos in os.walk(directorio_raiz):
        for archivo in archivos:
            if archivo.lower().endswith('.wav'):
                ruta_wav = os.path.join(raiz, archivo)
                tiene_loop, chunks = extraer_chunks_de_loop(ruta_wav)

                if not tiene_loop:
                    # No tiene loop, se salta (ya cubierto por el convertidor a MP3)
                    continue

                if es_ya_mono(ruta_wav):
                    print(f"[YA ES MONO]        {os.path.relpath(ruta_wav, directorio_raiz)}")
                    total_saltados += 1
                    continue

                ruta_temporal = os.path.join(raiz, f"temp_{archivo}")

                print(f"[OPTIMIZANDO LOOP]  {os.path.relpath(ruta_wav, directorio_raiz)} (Estéreo -> Mono 44.1kHz 16-bit)")

                # Convertir a Mono, 44.1kHz, 16-bit PCM
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
                    
                    # Restaurar los puntos de bucle en el nuevo archivo mono
                    inyectar_chunks(ruta_temporal, chunks)

                    # Reemplazar el archivo original por el optimizado
                    os.replace(ruta_temporal, ruta_wav)
                    total_optimizados += 1

                except subprocess.CalledProcessError:
                    print(f"[ERROR CONVERSIÓN] {ruta_wav}")
                    if os.path.exists(ruta_temporal):
                        os.remove(ruta_temporal)
                except Exception as e:
                    print(f"[ERROR INYECCIÓN]  {ruta_wav}: {e}")
                    if os.path.exists(ruta_temporal):
                        os.remove(ruta_temporal)

    print("\n-------------------------------------------")
    print(f"Finalizado: {total_optimizados} optimizados (50% menos peso) | {total_saltados} ya eran mono.")

if __name__ == "__main__":
    carpeta = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    procesar_loops(carpeta)
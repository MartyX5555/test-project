import os
import struct
import subprocess
import sys

def tiene_puntos_de_loop(ruta_wav):
    """
    Inspecciona los chunks RIFF del archivo WAV.
    Retorna True si contiene chunks 'cue ' o 'smpl' con bucles definidos.
    """
    try:
        with open(ruta_wav, 'rb') as f:
            header = f.read(12)
            if len(header) < 12 or header[:4] != b'RIFF' or header[8:12] != b'WAVE':
                return False  # No es un WAV estándar

            while True:
                chunk_header = f.read(8)
                if len(chunk_header) < 8:
                    break
                
                chunk_id, chunk_size = struct.unpack('<4sI', chunk_header)

                # 1. Chunk 'cue ' (utilizado frecuentemente por Sound Forge / Source)
                if chunk_id == b'cue ':
                    num_cues_raw = f.read(4)
                    if len(num_cues_raw) == 4:
                        num_cues = struct.unpack('<I', num_cues_raw)[0]
                        if num_cues > 0:
                            return True
                    # Si no hubo cues válidos, salta el resto del chunk
                    f.seek(max(0, chunk_size - 4), os.SEEK_CUR)

                # 2. Chunk 'smpl' (estándar de sampleo MIDI y bucles de sampler)
                elif chunk_id == b'smpl':
                    data = f.read(min(chunk_size, 36))
                    if len(data) >= 36:
                        # El número de loops de sampleo se almacena en el offset 28
                        num_loops = struct.unpack('<I', data[28:32])[0]
                        if num_loops > 0:
                            return True
                    restante = chunk_size - len(data)
                    if restante > 0:
                        f.seek(restante, os.SEEK_CUR)

                else:
                    # Saltar chunk que no interesa
                    f.seek(chunk_size, os.SEEK_CUR)

                # Los chunks en formato RIFF deben estar alineados a múltiplos de 2 bytes
                if chunk_size % 2 != 0:
                    f.seek(1, os.SEEK_CUR)

        return False
    except Exception as e:
        print(f"[ERROR] No se pudo leer {ruta_wav}: {e}")
        return False

def procesar_carpeta(directorio_raiz):
    total_convertidos = 0
    total_ignorados = 0

    print(f"Buscando archivos en: {directorio_raiz}\n")

    # Recorrido recursivo por todas las carpetas y subcarpetas
    for raiz, _, archivos in os.walk(directorio_raiz):
        for archivo in archivos:
            if archivo.lower().endswith('.wav'):
                ruta_wav = os.path.join(raiz, archivo)
                nombre_base, _ = os.path.splitext(ruta_wav)
                ruta_mp3 = f"{nombre_base}.mp3"

                if tiene_puntos_de_loop(ruta_wav):
                    print(f"[SALTADO - TIENE LOOP] {os.path.relpath(ruta_wav, directorio_raiz)}")
                    total_ignorados += 1
                else:
                    print(f"[CONVIRTIENDO]         {os.path.relpath(ruta_wav, directorio_raiz)} -> MP3")
                    
                    # Ejecutar ffmpeg con configuración 44.1kHz CBR para GMod
                    cmd = [
                        'ffmpeg', '-y', '-v', 'error',
                        '-i', ruta_wav,
                        '-vn',
                        '-ar', '44100',
                        '-ac', '2',
                        '-b:a', '192k',
                        '-c:a', 'libmp3lame',
                        ruta_mp3
                    ]
                    
                    try:
                        subprocess.run(cmd, check=True)
                        total_convertidos += 1
                        os.remove(ruta_wav)
                    except subprocess.CalledProcessError:
                        print(f"[ERROR AL CONVERTIR]   {ruta_wav}")
                    except FileNotFoundError:
                        print("\n[CRÍTICO] No se encontró 'ffmpeg' en el sistema. Asegúrate de tenerlo instalado y en el PATH.")
                        return

    print("\n-------------------------------------------")
    print(f"Completado: {total_convertidos} convertidos | {total_ignorados} ignorados por tener loop.")

if __name__ == "__main__":
    # Si pasas una ruta por argumento, usa esa; si no, toma la carpeta donde está el script
    if len(sys.argv) > 1:
        carpeta_objetivo = sys.argv[1]
    else:
        carpeta_objetivo = os.path.dirname(os.path.abspath(__file__))

    procesar_carpeta(carpeta_objetivo)
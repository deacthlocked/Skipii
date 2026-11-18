cat << 'EOF' > ~/lab/scripts/net_quad_tool.py
#!/usr/bin/env python3
import subprocess
import sys
import math

def resolver_cuadratica(a, b, c):
    print(f"\n[⚙️] Analizando ecuación cuadrática: {a}x² + {b}x + {c} = 0")
    discriminante = (b**2) - (4*a*c)
    print(f"    Discriminante ($\Delta$): {discriminante}")
    
    if discriminante > 0:
        x1 = (-b + math.sqrt(discriminante)) / (2*a)
        x2 = (-b - math.sqrt(discriminante)) / (2*a)
        print(f"    ✅ Dos raíces reales distintas:")
        print(f"       x1 = {x1:.4f}")
        print(f"       x2 = {x2:.4f}")
    elif discriminante == 0:
        x = -b / (2*a)
        print(f"    ✅ Una raíz real única (repetida):")
        print(f"       x = {x:.4f}")
    else:
        real = -b / (2*a)
        imaginaria = math.sqrt(abs(discriminante)) / (2*a)
        print(f"    ⚠️ Raíces complejas (conjugadas):")
        print(f"       x1 = {real:.4f} + {imaginaria:.4f}i")
        print(f"       x2 = {real:.4f} - {imaginaria:.4f}i")

def consultar_red_termux():
    print("==================================================")
    print("       DIAGNOSTICO DE RED - ESPACIO TERMUX       ")
    print("==================================================")

    # Interfaces de red activas
    print("\n[+] Consultando interfaces de red activas...")
    try:
        resultado_if = subprocess.run(['ip', '-brief', 'address'], capture_output=True, text=True, check=True)
        print(resultado_if.stdout if resultado_if.stdout else "No se encontraron interfaces activas o el comando está limitado.")
    except Exception as e:
        print(f"    [Error] No se pudo ejecutar 'ip -brief address': {e}")

    # Tabla de enrutamiento IPv4
    print("\n[+] Tabla de enrutamiento IPv4:")
    try:
        resultado_v4 = subprocess.run(['ip', 'route', 'show'], capture_output=True, text=True, check=True)
        print(resultado_v4.stdout if resultado_v4.stdout else "Sin rutas IPv4 disponibles.")
    except Exception as e:
        print(f"    [Error] No se pudo consultar IPv4: {e}")

    # Tabla de enrutamiento IPv6
    print("\n[+] Tabla de enrutamiento IPv6:")
    try:
        resultado_v6 = subprocess.run(['ip', '-6', 'route', 'show'], capture_output=True, text=True, check=True)
        print(resultado_v6.stdout if resultado_v6.stdout else "Sin rutas IPv6 disponibles.")
    except Exception as e:
        print(f"    [Error] No se pudo consultar IPv6: {e}")

if __name__ == "__main__":
    consultar_red_termux()
    
    print("\n==================================================")
    print("          MÓDULO DE ECUACIÓN CUADRÁTICA          ")
    print("==================================================")
    
    # Puedes modificar estos coeficientes o hacerlos interactivos
    # Por defecto simulamos un cálculo de umbral de red
    a, b, c = 1, -4, 4
    resolver_cuadratica(a, b, c)
EOF

chmod +x ~/lab/scripts/net_quad_tool.py

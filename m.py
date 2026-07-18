import os
import shutil
import subprocess

# Repositório clonado
REPO = "/data/data/com.termux/files/home/Script-test"

# Pasta onde estão os .lua
ORIGEM = "/storage/emulated/0/Download/MiniMax"

USUARIO = "FelpzSystem"
REPOSITORIO = "Script-test"


def run(cmd):
    print(">", " ".join(cmd))
    subprocess.run(cmd, cwd=REPO, check=True)


def hospedar(token):
    enviados = []

    # Remove apenas os .lua do repositório
    for arquivo in os.listdir(REPO):
        if arquivo.endswith(".lua"):
            os.remove(os.path.join(REPO, arquivo))

    # Copia todos os .lua da pasta de origem
    for arquivo in os.listdir(ORIGEM):
        if arquivo.endswith(".lua"):
            shutil.copy2(
                os.path.join(ORIGEM, arquivo),
                os.path.join(REPO, arquivo)
            )
            enviados.append(arquivo)

    if not enviados:
        print("❌ Nenhum arquivo .lua encontrado.")
        return

    try:
        run(["git", "add", "."])

        # Commit (ignora caso não haja alterações)
        subprocess.run(
            ["git", "commit", "-m", "Atualização automática"],
            cwd=REPO
        )

        # Push usando o token diretamente
        run([
            "git",
            "push",
            f"https://x-access-token:{token}@github.com/{USUARIO}/{REPOSITORIO}.git",
            "HEAD:main"
        ])

        print("\n✅ Upload concluído!\n")

        for arquivo in enviados:
            print(
                f"https://raw.githubusercontent.com/{USUARIO}/{REPOSITORIO}/main/{arquivo}"
            )

    except subprocess.CalledProcessError as e:
        print("\n❌ ERRO!")
        print(e)


if __name__ == "__main__":
    # Pede o token corretamente no terminal
    token = input("Digite o seu Token do GitHub: ").strip()
    
    # Verifica se o usuário digitou algo antes de continuar
    if token:
        hospedar(token)
    else:
        print("❌ Erro: O token não pode ficar vazio. Tente rodar o script novamente.")
        
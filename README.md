# Projeto-GitHelper
Aplicativo para Windows com interface gráfica que simplifica o uso de Git e GitHub em equipe. Crie, clone e abra projetos, crie branches, registre alterações, publique e conclua o trabalho com poucos cliques, vendo cada comando Git executado em um log para aprender enquanto usa. Arquivo único .bat, sem instalação.


<div align="center">

# 🔀 GitHub Team Helper

**Git e GitHub para equipes, com interface gráfica e cada comando à vista.**

![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)
![Git](https://img.shields.io/badge/Git-necessário-F05032?logo=git&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-incluído%20no%20Windows-5391FE?logo=powershell&logoColor=white)
![Arquivo único](https://img.shields.io/badge/arquivo-único%20.bat-7c3aed)
![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-22c55e)

</div>

---

## 📖 Sobre

O **GitHub Team Helper** é uma ferramenta de arquivo único (`.bat`) com interface gráfica em Windows Forms. Ela guia o fluxo de trabalho em equipe com Git e GitHub: criar branches, registrar alterações, publicar e integrar na `main`.

Cada ação mostra **o comando Git que será executado**, pede confirmação quando há risco e registra tudo em um **log**. Assim, você usa a ferramenta e aprende Git ao mesmo tempo.

## ✨ Destaques

- 🖱️ **Interface gráfica** moderna, com tema escuro
- 📦 **Arquivo único**: dê dois cliques no `.bat`, sem instalação nem dependências extras
- 🧾 **Log de comandos** em tempo real, com o comando, o resultado e o status
- 🛡️ **Seguro por padrão**: confirmações, sem `--force` e sem alterar a configuração global do Git
- 🌿 **Grafo de branches** colorido, mostrando onde você está (HEAD)
- 🔐 **Remoção de credenciais** do GitHub salvas no Windows

## ⚙️ Requisitos

| Requisito | Detalhes |
|---|---|
| Sistema | Windows 10 ou 11 |
| Git | [Baixar o Git para Windows](https://git-scm.com/download/win) |
| PowerShell | Já incluído no Windows |

## 🚀 Como usar

1. Baixe o arquivo `.bat` deste repositório.
2. Dê **dois cliques** para abrir.
3. Escolha **Novo Projeto**, **Clonar Repositório** ou **Abrir Projeto Existente**.
4. Use os cards do painel e acompanhe os comandos no log.

> 💡 O arquivo lê a si mesmo e executa o código embutido no PowerShell do Windows. Nenhum outro arquivo é necessário.

## 🧭 Telas iniciais

| Opção | O que faz | Comando |
|---|---|---|
| **Novo Projeto** | Cria uma pasta, inicia o repositório e define `main` como branch inicial | `git init` |
| **Clonar Repositório** | Baixa um projeto do GitHub para o seu computador | `git clone` |
| **Abrir Projeto Existente** | Usa uma pasta que já é um repositório (nada é recriado) | — |

## 🎛️ Painel do projeto

| Card | O que faz | Comando |
|---|---|---|
| **Atualizar Projeto** | Traz as novidades do GitHub | `git pull origin` |
| **Criar Branch** | Cria e entra em uma nova branch de trabalho | `git switch -c` |
| **Registrar Alterações** | Adiciona todos os arquivos ou arquivos específicos e cria o commit | `git add` + `git commit` |
| **Publicar Branch** | Atualiza com a `main` e envia a branch ao GitHub | `git merge main` + `git push -u` |
| **Concluir Trabalho** ⚠️ | Integra na `main`, envia e remove a branch local (exige digitar `CONFIRMAR`) | `merge` + `push` + `branch -d` |
| **Status** | Mostra a situação atual do repositório | `git status` |

## 🧰 Mais comandos individuais

| Comando | Função |
|---|---|
| `git branch` | Lista as branches locais e permite trocar de uma delas |
| `git switch` | Muda para outra branch existente |
| `git branch -d` | Exclui uma branch local já integrada (modo seguro) |
| `git merge <branch>` | Traz outra branch para a branch atual |
| `git fetch origin` | Baixa as novidades sem mexer nos seus arquivos |
| `git push` | Envia a branch atual ao GitHub |
| `git add .` | Marca todas as alterações para o próximo commit |
| `git stash` | Guarda temporariamente as alterações em andamento |
| `git stash pop` | Recupera as alterações guardadas |
| `git log --graph` | Mostra o histórico em formato de grafo |
| `git diff --stat` | Resume o que mudou desde o último commit |
| `git remote -v` | Mostra os remotos configurados |

## 🌿 Grafo de branches

Exibe os **80 commits mais recentes** com:

- linhas coloridas, uma para cada branch;
- rótulos de branches, tags e remotos;
- hash, autor e data de cada commit;
- o commit atual (HEAD) em destaque.

## 👤 Usuário e credenciais

- **Usuário**: configura nome e e-mail apenas no projeto atual (`git config --local`), nunca de forma global.
- **Credenciais**: lista e remove os logins do GitHub salvos no Gerenciador de Credenciais do Windows, com confirmação antes de apagar. Os repositórios e arquivos não são afetados, e o login será pedido novamente no próximo `pull`, `push` ou `clone`.

## 🛡️ Segurança e boas práticas

- ✅ Confirmação antes de operações que alteram o repositório
- ✅ Nenhum `--force`, e a exclusão de branches usa sempre `-d` (o Git recusa se houver commits não integrados)
- ✅ Nenhuma pasta existente é apagada ou sobrescrita
- ✅ Detecção de conflitos de merge, com instruções claras
- ✅ O Git nunca trava esperando entrada no terminal
- ✅ Erros inesperados são tratados sem derrubar a interface

## 🔄 Fluxo de trabalho sugerido

```text
Atualizar Projeto  →  Criar Branch  →  Registrar Alterações
        →  Publicar Branch  →  (Pull Request no GitHub)  →  Concluir Trabalho
```

## 🗂️ Estrutura interna do código

O arquivo é dividido em módulos: núcleo (estado, cores, desenho, botões, diálogos, log e execução do Git), pintura (cards, banner e grafo), menus, ações de projeto e branches, tratamento de erros e saída.

## 🤝 Contribuindo

Sugestões e melhorias são bem-vindas! Abra uma *issue* ou envie um *pull request*.


## 📄 Licença

Distribuído sob a licença **MIT**. Veja o arquivo [`LICENSE`](LICENSE) para mais detalhes.

![License: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-green.svg)

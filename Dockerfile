FROM golang:1.13.5-alpine

# 1.13.5-alpine3.11, 1.13-alpine3.11, 1-alpine3.11, alpine3.11, 1.13.5-alpine, 1.13-alpine, 1-alpine, alpine

LABEL maintainer "https://github.com/blacktop"

RUN apk add --no-cache ca-certificates git python3 ctags tzdata bash neovim neovim-doc

######################
### SETUP ZSH/TMUX ###
######################

RUN apk add --no-cache zsh tmux && rm -rf /tmp/*

RUN git clone git://github.com/robbyrussell/oh-my-zsh.git /root/.oh-my-zsh
RUN git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm
RUN git clone https://github.com/tmux-plugins/tmux-cpu /root/.tmux/plugins/tmux-cpu
RUN git clone https://github.com/tmux-plugins/tmux-prefix-highlight /root/.tmux/plugins/tmux-prefix-highlight

COPY tmux.conf /root/.tmux.conf
COPY tmux.linux.conf /root/.tmux.linux.conf

####################
### SETUP NEOVIM ###
####################

# Install vim plugin manager
RUN apk add --no-cache curl \
  && curl -fLo /root/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
  && rm -rf /tmp/* \
  && apk del --purge curl

# Install vim plugins
RUN apk add --no-cache -t .build-deps build-base python3-dev \
  && pip3 install -U neovim \
  && rm -rf /tmp/* \
  && apk del --purge .build-deps

RUN mkdir -p /root/.config/nvim
COPY vimrc /root/.config/nvim/init.vim
RUN ln -s /root/.config/nvim/init.vim /root/.vimrc

COPY nvim/snippets /root/.config/nvim/snippets
COPY nvim/spell /root/.config/nvim/spell

# Go get popular golang libs
RUN echo "===> go get popular golang libs..." \
  && go get -u github.com/go-delve/delve/cmd/dlv \
  && go get -u github.com/sirupsen/logrus \
  && go get -u github.com/spf13/cobra/cobra \
  && go get -u github.com/golang/dep/cmd/dep \
  && go get -u github.com/fatih/structs \
  && go get -u github.com/gorilla/mux \
  && go get -u github.com/gorilla/handlers \
  && go get -u github.com/parnurzeal/gorequest \
  && go get -u github.com/urfave/cli \
  && go get -u github.com/apex/log/...
# Go get vim-go binaries
RUN echo "===> get vim-go binaries..." \
  && go get -u -v github.com/klauspost/asmfmt/cmd/asmfmt \
  && go get -u -v github.com/kisielk/errcheck \
  && go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct \
  && go get -u -v github.com/stamblerre/gocode \
  && go get -u -v github.com/rogpeppe/godef \
  && go get -u -v github.com/zmb3/gogetdoc \
  && go get -u -v golang.org/x/tools/cmd/goimports \
  && go get -u -v golang.org/x/lint/golint \
  && GO111MODULE=on go get -v golang.org/x/tools/gopls@latest \
  && go get -u -v github.com/alecthomas/gometalinter \
  && go get -u -v github.com/golangci/golangci-lint/cmd/golangci-lint \
  && go get -u -v github.com/fatih/gomodifytags \
  && go get -u -v golang.org/x/tools/cmd/gorename \
  && go get -u -v github.com/jstemmer/gotags \
  && go get -u -v golang.org/x/tools/cmd/guru \
  && go get -u -v github.com/josharian/impl \
  && go get -u -v honnef.co/go/tools/cmd/keyify \
  && go get -u -v github.com/fatih/motion \
  && go get -u -v github.com/koron/iferr

# Install nvim plugins
RUN set -x; apk add --no-cache -t .build-deps build-base python3-dev \
  && echo "===> neovim PlugInstall..." \
  && nvim -i NONE -c PlugInstall -c quitall \
  && echo "===> neovim UpdateRemotePlugins..." \
  && nvim -i NONE -c UpdateRemotePlugins -c quitall \
  && rm -rf /tmp/* \
  && apk del --purge .build-deps

# Get powerline font just in case (to be installed on the docker host)
RUN apk add --no-cache wget \
  && mkdir /root/powerline \
  && cd /root/powerline \
  && wget https://github.com/powerline/fonts/raw/master/Meslo%20Slashed/Meslo%20LG%20M%20Regular%20for%20Powerline.ttf \
  && rm -rf /tmp/* \
  && apk del --purge wget

ENV TERM=screen-256color
# Setup Language Environtment
ENV LANG="C.UTF-8"
ENV LC_COLLATE="C.UTF-8"
ENV LC_CTYPE="C.UTF-8"
ENV LC_MESSAGES="C.UTF-8"
ENV LC_MONETARY="C.UTF-8"
ENV LC_NUMERIC="C.UTF-8"
ENV LC_TIME="C.UTF-8"


# shell-init: error retrieving current directory: getcwd: cannot access parent directories: Permission denied
# internal/process/main_thread_only.js:42
#     cachedCwd = binding.cwd();
#                         ^

# Error: EACCES: permission denied, uv_cwd
#     at process.cwd (internal/process/main_thread_only.js:42:25)
#     at Object.resolve (path.js:976:47)
#     at patchProcessObject (internal/bootstrap/pre_execution.js:73:28)
#     at prepareMainThreadExecution (internal/bootstrap/pre_execution.js:10:3)
#     at internal/main/run_main_module.js:7:1 {
#   errno: -13,
#   code: 'EACCES',
#   syscall: 'uv_cwd'
# }

# HOTFIX: https://github.com/embark-framework/embark/issues/1677
RUN apk add --no-cache --update nodejs npm xclip acl && rm -rf /tmp/* \
    && setfacl -dR -m u:root:rwX /usr/lib/node_modules \
    && setfacl -R -m u:root:rwX /usr/lib/node_modules \
    && setfacl -dR -m u:root:rwX /usr/local/bin/ \
    && setfacl -R -m u:root:rwX /usr/local/bin \
    && npm config set user 0 \
    && npm config set unsafe-perm true \
    && npm install --global pure-prompt

# RUN apk add --no-cache --update nodejs npm xclip && rm -rf /tmp/*

RUN git clone https://github.com/zsh-users/antigen.git /root/.antigen/antigen
# RUN go get -d -v github.com/maliceio/engine/...

# COPY zshrc.pure /root/.zshrc.pure
COPY zshrc.pure /root/.zshrc
# COPY zshrc /root/.zshrc

# RUN git clone https://github.com/junegunn/fzf.git -b 0.18.0 ~/.fzf
RUN cd ~/.fzf; ./install --all

RUN apk --no-cache add fontconfig && rm -rf /tmp/*

# RUN mkdir -p $HOME/.fonts $HOME/.config/fontconfig/conf.d \
#   && wget -P $HOME/.fonts https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf \
#   && wget -P $HOME/.config/fontconfig/conf.d/ https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf \
#   && fc-cache -vf $HOME/.fonts/

# SOURCE: https://github.com/veggiemonk/ansible-dotfiles/blob/master/tasks/fonts.yml
RUN git clone https://github.com/powerline/fonts ~/powerlinefonts && \
  cd ~/powerlinefonts; ~/powerlinefonts/install.sh \
  && fc-cache -f

COPY bin/ /entrypoints

RUN /entrypoints/install-fonts

ENTRYPOINT ["tmux"]

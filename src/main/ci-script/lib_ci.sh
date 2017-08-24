
echo "CI_BUILD_REF_NAME: ${CI_BUILD_REF_NAME}"
echo "CI_COMMIT_REF_NAME: ${CI_COMMIT_REF_NAME}"
echo "CI_PROJECT_URL: ${CI_PROJECT_URL}"
echo "TRAVIS_BRANCH: ${TRAVIS_BRANCH}"
echo "TRAVIS_EVENT_TYPE: ${TRAVIS_EVENT_TYPE}"
echo "TRAVIS_REPO_SLUG: ${TRAVIS_REPO_SLUG}"

### OSS CI INFRASTRUCTURE VARIABLES BEGIN
if [ -z "${GITHUB_DOCKER_REGISTRY}" ]; then GITHUB_DOCKER_REGISTRY="home1oss"; fi
if [ -z "${GITHUB_INFRASTRUCTURE_CONF_GIT_PREFIX}" ]; then GITHUB_INFRASTRUCTURE_CONF_GIT_PREFIX="https://github.com"; fi
echo "GITHUB_INFRASTRUCTURE_CONF_GIT_PREFIX: ${GITHUB_INFRASTRUCTURE_CONF_GIT_PREFIX}"
if [ -z "${INTERNAL_DOCKER_REGISTRY}" ]; then INTERNAL_DOCKER_REGISTRY="registry.docker.internal"; fi
echo "INTERNAL_DOCKER_REGISTRY: ${INTERNAL_DOCKER_REGISTRY}"
if [ -z "${INTERNAL_INFRASTRUCTURE_CONF_GIT_PREFIX}" ]; then INTERNAL_INFRASTRUCTURE_CONF_GIT_PREFIX="http://gitlab.internal"; fi
echo "INTERNAL_INFRASTRUCTURE_CONF_GIT_PREFIX: ${INTERNAL_INFRASTRUCTURE_CONF_GIT_PREFIX}"
if [ -z "${INTERNAL_NEXUS3}" ]; then INTERNAL_NEXUS3="http://nexus3.internal:28081"; fi
echo "INTERNAL_NEXUS3: ${INTERNAL_NEXUS3}"
if [ -z "${LOCAL_DOCKER_REGISTRY}" ]; then LOCAL_DOCKER_REGISTRY="registry.docker.local"; fi
echo "LOCAL_DOCKER_REGISTRY: ${LOCAL_DOCKER_REGISTRY}"
if [ -z "${LOCAL_INFRASTRUCTURE_CONF_GIT_PREFIX}" ]; then LOCAL_INFRASTRUCTURE_CONF_GIT_PREFIX="http://gitlab.local:10080"; fi
echo "LOCAL_INFRASTRUCTURE_CONF_GIT_PREFIX: ${LOCAL_INFRASTRUCTURE_CONF_GIT_PREFIX}"
if [ -z "${LOCAL_NEXUS3}" ]; then LOCAL_NEXUS3="http://nexus3.local:28081"; fi
echo "LOCAL_NEXUS3: ${LOCAL_NEXUS3}"
### OSS CI INFRASTRUCTURE VARIABLES END

### FUNCTIONS BEGIN
# arguments: target_file
function filter_script() {
    local target_file="$1"

cat >${target_file} <<EOL
# filter log output
# reduce log avoid travis 4MB limit
while IFS='' read -r LINE
do
    echo "\${LINE}" \
        | grep -v 'Downloading:' \
        | grep -Ev '^Progress ' \
        | grep -Ev '^Generating .+\.html\.\.\.'
done
EOL

    chmod 755 ${target_file}
    echo "${target_file}"
}

# ${CI_PROJECT_URL} example: "https://example.com/gitlab-org/gitlab-ce"
# arguments:
function infrastructure() {
    if [ -n "${CI_PROJECT_URL}" ]; then
        if [[ "${CI_PROJECT_URL}" == ${INTERNAL_INFRASTRUCTURE_CONF_GIT_PREFIX}* ]]; then
            echo "internal"
        else
            echo "local"
        fi
    elif [ -n "${TRAVIS_REPO_SLUG}" ]; then
        echo "github"
    else
        echo "local"
    fi
}

function infrastructure_conf_git_prefix() {
    local infrastructure="$(infrastructure)"
    if [ "internal" == "${INFRASTRUCTURE}" ]; then
        if [ -z "${CI_PROJECT_URL}" ]; then
            echo "${INTERNAL_INFRASTRUCTURE_CONF_GIT_PREFIX}"
        else
            echo $(echo "${CI_PROJECT_URL}" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,')
        fi
    elif [ "github" == "${INFRASTRUCTURE}" ]; then
        echo "${GITHUB_INFRASTRUCTURE_CONF_GIT_PREFIX}"
    else
        echo "${LOCAL_INFRASTRUCTURE_CONF_GIT_PREFIX}"
    fi
}

function is_config_repository() {
    if [[ "$(basename $(pwd))" == *-config ]] && ([ -f "application.yml" ] || [ -f "application.properties" ]); then
        return
    fi
    false
}

# arguments:
function maven_skip_clean_and_tests() {
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.clean.skip=true -Dmaven.test.skip=true -Dmaven.integration-test.skip=true"
}

# arguments: ref_name
function publish_channel() {
    case "${1}" in
        "develop")
            echo "snapshot"
            ;;
        "master")
            echo "release"
            ;;
        release*)
            echo "release"
            ;;
        *)
            echo "snapshot"
            ;;
    esac
}

# ${CI_BUILD_REF_NAME} show branch or tag since GitLab-CI 5.2
# CI_BUILD_REF_NAME for gitlab 8.x, see: https://gitlab.com/help/ci/variables/README.md
# CI_COMMIT_REF_NAME for gitlab 9.x, see: https://gitlab.com/help/ci/variables/README.md
# TRAVIS_BRANCH for travis-ci, see: https://docs.travis-ci.com/user/environment-variables/
# arguments:
function ref_name() {
    if [ -n "${CI_BUILD_REF_NAME}" ]; then
        echo "${CI_BUILD_REF_NAME}"
    elif [ -n "${CI_COMMIT_REF_NAME}" ]; then
        echo "${CI_COMMIT_REF_NAME}"
    elif [ -n "${TRAVIS_BRANCH}" ]; then
        echo "${TRAVIS_BRANCH}"
    else
        echo "$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)"
    fi
}
### FUNCTIONS END

### DECRYPT SOME FILES BEGIN
### DECRYPT SOME FILES END

if [ -f "${HOME}/.bashrc" ]; then source "${HOME}/.bashrc"; fi
echo "PWD: $(pwd)"
echo "USER: $(whoami)"

### OSS CI CONTEXT VARIABLES BEGIN
if [ -z "${INFRASTRUCTURE}" ]; then INFRASTRUCTURE="$(infrastructure)"; fi
echo "INFRASTRUCTURE: ${INFRASTRUCTURE}"
export INFRASTRUCTURE
if [ -z "${LIB_CI_SCRIPT}" ]; then LIB_CI_SCRIPT="https://github.com/home1-oss/oss-build/raw/master/src/main/ci-script/lib_ci.sh"; fi
echo "LIB_CI_SCRIPT: ${LIB_CI_SCRIPT}"
# Use lib_common.sh at same location as lib_ci.sh
if [ -z "${LIB_COMMON_SCRIPT}" ]; then LIB_COMMON_SCRIPT="$(dirname ${LIB_CI_SCRIPT})/lib_common.sh"; fi
echo "LIB_COMMON_SCRIPT: ${LIB_COMMON_SCRIPT}"

# INFRASTRUCTURE specific values.
DOCKER_REGISTRY_VAR="$(echo ${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_DOCKER_REGISTRY"
if [ -n "$BASH_VERSION" ]; then DOCKER_REGISTRY="${!DOCKER_REGISTRY_VAR}"; elif [ -n "${ZSH_VERSION}" ]; then DOCKER_REGISTRY="${(P)DOCKER_REGISTRY_VAR}"; else echo "unsupported ${SHELL}"; fi
echo "DOCKER_REGISTRY: ${DOCKER_REGISTRY}"
export DOCKER_REGISTRY
#FILESERVER_VAR="$(echo ${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_FILESERVER"
#if [ -n "$BASH_VERSION" ]; then BUILD_FILESERVER="${!FILESERVER_VAR}"; elif [ -n "${ZSH_VERSION}" ]; then BUILD_FILESERVER="${(P)FILESERVER_VAR}"; else echo "unsupported ${SHELL}"; fi
if [ -z "${INFRASTRUCTURE_CONF_GIT_PREFIX}" ]; then INFRASTRUCTURE_CONF_GIT_PREFIX="$(infrastructure_conf_git_prefix)"; fi
echo "INFRASTRUCTURE_CONF_GIT_PREFIX: ${INFRASTRUCTURE_CONF_GIT_PREFIX}"
INFRASTRUCTURE_CONF_GIT_TOKEN_VAR="$(echo ${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_INFRASTRUCTURE_CONF_GIT_TOKEN"
if [ -z "${INFRASTRUCTURE_CONF_GIT_TOKEN}" ]; then
    if [ -n "$BASH_VERSION" ]; then INFRASTRUCTURE_CONF_GIT_TOKEN="${!INFRASTRUCTURE_CONF_GIT_TOKEN_VAR}"; elif [ -n "${ZSH_VERSION}" ]; then INFRASTRUCTURE_CONF_GIT_TOKEN="${(P)INFRASTRUCTURE_CONF_GIT_TOKEN_VAR}"; else echo "unsupported ${SHELL}"; fi
fi
if [ -z "${INFRASTRUCTURE_CONF_GIT_TOKEN}" ]; then echo "INFRASTRUCTURE_CONF_GIT_TOKEN not set, exit."; exit 1; else echo "INFRASTRUCTURE_CONF_GIT_TOKEN: *secret*"; fi

INFRASTRUCTURE_CONF_LOC="${INFRASTRUCTURE_CONF_GIT_PREFIX}/home1-oss/oss-${INFRASTRUCTURE}/raw/master"
echo "INFRASTRUCTURE_CONF_LOC: ${INFRASTRUCTURE_CONF_LOC}"

echo "eval \$(curl -H 'Cache-Control: no-cache' -L -s ${LIB_COMMON_SCRIPT})"
eval "$(curl -H 'Cache-Control: no-cache' -L -s ${LIB_COMMON_SCRIPT})"

# LOGGING_LEVEL_ is for spring-boot projects
export LOGGING_LEVEL_="INFO"
echo "LOGGING_LEVEL_: ${LOGGING_LEVEL_}"

if [ -z "${BUILD_COMMIT_ID}" ]; then BUILD_COMMIT_ID="$(git_commit_id)"; fi
echo "BUILD_COMMIT_ID: ${BUILD_COMMIT_ID}"
if [ -z "${BUILD_CACHE}" ]; then BUILD_CACHE="${HOME}/.oss/tmp/${BUILD_COMMIT_ID}"; fi
echo "BUILD_CACHE: ${BUILD_CACHE}"
mkdir -p ${BUILD_CACHE}
FILTER_SCRIPT=$(filter_script "${BUILD_CACHE}/filter")
echo "FILTER_SCRIPT: ${FILTER_SCRIPT}"
### OSS CI CONTEXT VARIABLES END

### Load lib scripts
set -e
# >>>>>>>>>> ---------- lib_docker ---------- >>>>>>>>>>
if [ ! -d "${HOME}/.docker/" ]; then echo "mkdir ${HOME}/.docker/ "; mkdir -p "${HOME}/.docker/"; fi

# Not all infrastructure has this file
curl_hidden="-H \"PRIVATE-TOKEN: \${INFRASTRUCTURE_CONF_GIT_TOKEN}\" -H 'Cache-Control: no-cache' -L -s -t utf-8 ${INFRASTRUCTURE_CONF_LOC}/src/main/docker/config.json"
echo "Test whether remote file exists: curl -I -o /dev/null -s -w \"%{http_code}\" ${curl_hidden} | tail -n1"
curl_response=$(curl -I -o /dev/null -s -w "%{http_code}" -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_CONF_GIT_TOKEN}" -H 'Cache-Control: no-cache' -L -s -t utf-8 ${INFRASTRUCTURE_CONF_LOC}/src/main/docker/config.json | tail -n1) || echo "error reading remote file."
echo "curl_response: ${curl_response}"
if [ "200" == "${curl_response}" ]; then
    echo "Download file: curl -o ${HOME}/.docker/config.json ${curl_hidden} > /dev/null"
    curl -o ${HOME}/.docker/config.json -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_CONF_GIT_TOKEN}" -H 'Cache-Control: no-cache' -L -s -t utf-8 ${INFRASTRUCTURE_CONF_LOC}/src/main/docker/config.json > /dev/null
fi
# TODO NEXUS3_DEPLOYMENT_PASSWORD for docker login when using internal infrastructure
if [ -n "${DOCKERHUB_PASS}" ] && [ -n "${DOCKERHUB_USER}" ]; then
    docker login -p="${DOCKERHUB_PASS}" -u="${DOCKERHUB_USER}" https://registry-1.docker.io/v1/
    docker login -p="${DOCKERHUB_PASS}" -u="${DOCKERHUB_USER}" https://registry-1.docker.io/v2/
fi
# <<<<<<<<<< ---------- lib_docker ---------- <<<<<<<<<<

# >>>>>>>>>> ---------- lib_maven ---------- >>>>>>>>>>
maven_pull_base_image() {
    # TODO multi module project
    if type -p docker > /dev/null; then
        if [ -f src/main/resources/docker/Dockerfile ]; then
            if [ ! -f src/main/docker/Dockerfile ]; then
                mvn ${MAVEN_SETTINGS} process-resources
            fi
            if [ -f src/main/docker/Dockerfile ]; then
                docker pull $(cat src/main/docker/Dockerfile | grep -E '^FROM' | awk '{print $2}')
            fi
        fi
    fi
}

maven_analysis() {
    if is_config_repository; then
        echo "maven_analysis config repository"
        mvn ${MAVEN_SETTINGS} -U clean package | ${FILTER_SCRIPT}
    elif [ "${BUILD_SKIP_SONAR}" != "true" ]; then
        echo "maven_analysis sonar"
        mvn ${MAVEN_SETTINGS} -U sonar:sonar
    fi
}

maven_clean() {
    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        mvn ${MAVEN_SETTINGS} -U clean org.apache.maven.plugins:maven-antrun-plugin:run@clean-local-deploy-dir
    else
        mvn ${MAVEN_SETTINGS} -U clean
    fi
}

# for maven multi-module project, that must execute 'mvn clean install' and 'mvn clean && mvn install' not works.
maven_clean_test_and_build() {
    echo "maven_clean_test_and_build"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.skip=${BUILD_TEST_SKIP}"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.integration-test.skip=${BUILD_INTEGRATION_TEST_SKIP}"

    maven_pull_base_image
    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        mvn ${MAVEN_SETTINGS} -U clean org.apache.maven.plugins:maven-antrun-plugin:run@clean-local-deploy-dir deploy | ${FILTER_SCRIPT}
    else
        mvn ${MAVEN_SETTINGS} -U clean install | ${FILTER_SCRIPT}
    fi
}

# if BUILD_PUBLISH_DEPLOY_SEGREGATION==true, no docker image is built at package phase.
# see profile 'skip-docker-plugin-lifecycle-binding-when-publish-deploy-segregation' in oss-build/pom.xml.
maven_test_and_build() {
    echo "maven_test_and_build"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.skip=${BUILD_TEST_SKIP}"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.integration-test.skip=${BUILD_INTEGRATION_TEST_SKIP}"

    maven_pull_base_image
    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        mvn ${MAVEN_SETTINGS} -U deploy | ${FILTER_SCRIPT}
    else
        mvn ${MAVEN_SETTINGS} -U install | ${FILTER_SCRIPT}
    fi
}

maven_publish_artifact() {
    echo "maven_publish_artifact"
    maven_skip_clean_and_tests

    #mvn ${MAVEN_SETTINGS} help:active-profiles
    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        mvn ${MAVEN_SETTINGS} -U org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@deploy-merge-maven-repos docker:build docker:push | ${FILTER_SCRIPT}
    else
        mvn ${MAVEN_SETTINGS} -U deploy | ${FILTER_SCRIPT}
    fi
}

maven_publish_site(){
    echo "maven_publish_site"
    maven_skip_clean_and_tests

    # deploy first, then build site
    if [ "github" == "${INFRASTRUCTURE}" ]; then
        # -X enable debug logging for Maven to avoid build timeout
        mvn ${MAVEN_SETTINGS} -U site site-deploy | ${FILTER_SCRIPT}
    else
        echo yes | mvn ${MAVEN_SETTINGS} -U site:site site:stage site:stage-deploy | ${FILTER_SCRIPT}
    fi
}

# Not all infrastructure has this file
curl_hidden="-H \"PRIVATE-TOKEN: \${INFRASTRUCTURE_CONF_GIT_TOKEN}\" -H 'Cache-Control: no-cache' -L -s -t utf-8 ${INFRASTRUCTURE_CONF_LOC}/src/main/maven/settings-security.xml"
echo "Test whether remote file exists: curl -I -o /dev/null -s -w \"%{http_code}\" ${curl_hidden} | tail -n1"
curl_response=$(curl -I -o /dev/null -s -w "%{http_code}" -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_CONF_GIT_TOKEN}" -H 'Cache-Control: no-cache' -L -s -t utf-8 ${INFRASTRUCTURE_CONF_LOC}/src/main/maven/settings-security.xml | tail -n1) || echo "error reading remote file."
echo "curl_response: ${curl_response}"
if [ "200" == "${curl_response}" ]; then
    echo "Download file: curl -o ${HOME}/.m2/settings-security.xml ${curl_hidden} > /dev/null"
    curl -o ${HOME}/.m2/settings-security.xml -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_CONF_GIT_TOKEN}" -H 'Cache-Control: no-cache' -L -s -t utf-8 ${INFRASTRUCTURE_CONF_LOC}/src/main/maven/settings-security.xml > /dev/null
fi

if [ -z "${BUILD_REF_NAME}" ]; then BUILD_REF_NAME="$(ref_name)"; fi
echo "BUILD_REF_NAME: ${BUILD_REF_NAME}"
if [ -z "${BUILD_PUBLISH_CHANNEL}" ]; then BUILD_PUBLISH_CHANNEL=$(publish_channel "${BUILD_REF_NAME}"); fi
echo "BUILD_PUBLISH_CHANNEL: ${BUILD_PUBLISH_CHANNEL}"

if [ -z "${BUILD_DEPENDENCY_CHECK}" ]; then BUILD_DEPENDENCY_CHECK="false"; fi
echo "BUILD_DEPENDENCY_CHECK: ${BUILD_DEPENDENCY_CHECK}"
if [ -z "${BUILD_GITHUB_SITE_REPO_NAME}" ]; then BUILD_GITHUB_SITE_REPO_NAME="home1-oss"; fi
echo "BUILD_GITHUB_SITE_REPO_NAME: ${BUILD_GITHUB_SITE_REPO_NAME}"
export BUILD_GITHUB_SITE_REPO_NAME
if [ -z "${BUILD_GITHUB_SITE_REPO_OWNER}" ]; then BUILD_GITHUB_SITE_REPO_OWNER="home1-oss"; fi
echo "BUILD_GITHUB_SITE_REPO_OWNER: ${BUILD_GITHUB_SITE_REPO_OWNER}"
export BUILD_GITHUB_SITE_REPO_OWNER
if [ -z "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then BUILD_PUBLISH_DEPLOY_SEGREGATION="false"; fi
echo "BUILD_PUBLISH_DEPLOY_SEGREGATION: ${BUILD_PUBLISH_DEPLOY_SEGREGATION}"
if [ -z "${BUILD_SITE}" ]; then BUILD_SITE="false"; fi
echo "BUILD_SITE: ${BUILD_SITE}"
if [ -z "${BUILD_SITE_PATH_PREFIX}" ]; then BUILD_SITE_PATH_PREFIX="oss"; fi
echo "BUILD_SITE_PATH_PREFIX: ${BUILD_SITE_PATH_PREFIX}"
if [ -z "${BUILD_TEST_FAILURE_IGNORE}" ]; then BUILD_TEST_FAILURE_IGNORE="false"; fi
echo "BUILD_TEST_FAILURE_IGNORE: ${BUILD_TEST_FAILURE_IGNORE}"
if [ -z "${BUILD_TEST_SKIP}" ]; then BUILD_TEST_SKIP="false"; fi
echo "BUILD_TEST_SKIP: ${BUILD_TEST_SKIP}"
if [ -z "${BUILD_INTEGRATION_TEST_SKIP}" ]; then BUILD_INTEGRATION_TEST_SKIP="false"; fi
if [ "${BUILD_TEST_SKIP}" == "true" ]; then BUILD_INTEGRATION_TEST_SKIP="true"; fi
echo "BUILD_INTEGRATION_TEST_SKIP: ${BUILD_INTEGRATION_TEST_SKIP}"

# 配置maven选项
# frontend.nodeDownloadRoot
# https://nodejs.org/dist/v6.9.1/node-v6.9.1-darwin-x64.tar.gz
# https://npm.taobao.org/mirrors/node/v6.9.1/node-v6.9.1-darwin-x64.tar.gz
#
# frontend.npmDownloadRoot
# http://registry.npmjs.org/npm/-/npm-3.10.8.tgz
# http://registry.npm.taobao.org/npm/-/npm-3.10.8.tgz
#
#echo "Execute following commands
#npm config set registry \${NEXUS}/nexus/repository/npm-public/
#npm config set cache \${HOME}/.npm/.cache/npm
#npm config set disturl \${NEXUS}/nexus/repository/npm-dist/
#npm config set sass_binary_site \${NEXUS}/nexus/repository/npm-sass/
#or edit \${HOME}/.npmrc file
#registry=\${NEXUS}/nexus/repository/npm-public/
#cache=\${HOME}/.npm/.cache/npm
#disturl=\${NEXUS}/nexus/repository/npm-dist/
#sass_binary_site=\${NEXUS}/nexus/repository/npm-sass/"

# TODO internal-sonar.host.url frontend ...
export MAVEN_OPTS="${MAVEN_OPTS} -Dbuild.publish.channel=${BUILD_PUBLISH_CHANNEL}"
export MAVEN_OPTS="${MAVEN_OPTS} -Ddependency-check=${BUILD_DEPENDENCY_CHECK}"
export MAVEN_OPTS="${MAVEN_OPTS} -Ddocker.registry=${DOCKER_REGISTRY}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dfile.encoding=UTF-8"
export MAVEN_OPTS="${MAVEN_OPTS} -Dinfrastructure=${INFRASTRUCTURE}"
if [ -n "${INTERNAL_NEXUS3}" ]; then export MAVEN_OPTS="${MAVEN_OPTS} -Dinternal-nexus3.repository=${INTERNAL_NEXUS3}/nexus/repository"; fi
if [ -n "${LOCAL_NEXUS3}" ]; then export MAVEN_OPTS="${MAVEN_OPTS} -Dlocal-nexus3.repository=${LOCAL_NEXUS3}/nexus/repository"; fi
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.failure.ignore=${BUILD_TEST_FAILURE_IGNORE}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dsite=${BUILD_SITE} -Dsite.path=${BUILD_SITE_PATH_PREFIX}-${BUILD_PUBLISH_CHANNEL}"
export MAVEN_OPTS="${MAVEN_OPTS} -Duser.language=zh -Duser.region=CN -Duser.timezone=Asia/Shanghai"

# 本地Repo临时地址，后续发布会从此目录deploy到远程仓库
LOCAL_DEPLOY_REPO="${HOME}/.oss/local-deploy/${BUILD_COMMIT_ID}"
echo "LOCAL_DEPLOY_REPO: ${LOCAL_DEPLOY_REPO}"
if [ ! -d "${LOCAL_DEPLOY_REPO}" ]; then mkdir -p ${LOCAL_DEPLOY_REPO}; fi

if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
    export MAVEN_OPTS="${MAVEN_OPTS} -Dpublish_deploy_segregation=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.source.filepath=${LOCAL_DEPLOY_REPO} -DaltDeploymentRepository=repo::default::file://${LOCAL_DEPLOY_REPO}"
    if [ "github" == "${INFRASTRUCTURE}" ]; then
        export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.merge-maven-repos.target=https://oss.sonatype.org/content/repositories/snapshots"
        export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.merge-maven-repos.target=https://oss.sonatype.org/service/local/staging/deploy/maven2"
    fi
fi

# CheckStyle and PMD config or rule location
if [ -n "${CHECKSTYLE_CONFIG_LOCATION}" ]; then echo "CHECKSTYLE_CONFIG_LOCATION: ${CHECKSTYLE_CONFIG_LOCATION}"; export MAVEN_OPTS="${MAVEN_OPTS} -Dcheckstyle.config.location=${CHECKSTYLE_CONFIG_LOCATION}"; fi
if [ -n "${PMD_RULESET_LOCATION}" ]; then echo "PMD_RULESET_LOCATION: ${PMD_RULESET_LOCATION}"; export MAVEN_OPTS="${MAVEN_OPTS} -Dpmd.ruleset.location=${PMD_RULESET_LOCATION}"; fi

# load infrastructure specific ci options
CI_OPTS_FILE="src/main/ci-script/ci_opts_${INFRASTRUCTURE}.sh"
if [ ! -f "${CI_OPTS_FILE}" ]; then
    CI_OPTS_FILE="${INFRASTRUCTURE_CONF_LOC}/src/main/ci-script/ci_opts.sh"
    echo "eval \$(curl -H 'Cache-Control: no-cache' -H \"PRIVATE-TOKEN: \${INFRASTRUCTURE_CONF_GIT_TOKEN}\" -s -L ${CI_OPTS_FILE})"
    eval "$(curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_CONF_GIT_TOKEN}" -s -L ${CI_OPTS_FILE})"
else
    . ${CI_OPTS_FILE}
fi
echo "CI_OPTS_FILE: ${CI_OPTS_FILE}"

MAVEN_SETTINGS_FILE="$(pwd)/src/main/maven/settings-${INFRASTRUCTURE}.xml"
if [ ! -f "${MAVEN_SETTINGS_FILE}" ]; then
    MAVEN_SETTINGS_FILE="${BUILD_CACHE}/settings-${INFRASTRUCTURE}-${BUILD_COMMIT_ID}.xml"
    curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${INFRASTRUCTURE_CONF_GIT_TOKEN}" -t utf-8 -s -L -o ${MAVEN_SETTINGS_FILE} ${INFRASTRUCTURE_CONF_LOC}/src/main/maven/settings.xml
    echo "curl -H 'Cache-Control: no-cache' -H \"PRIVATE-TOKEN: \${INFRASTRUCTURE_CONF_GIT_TOKEN}\" -t utf-8 -s -L -o ${MAVEN_SETTINGS_FILE} ${INFRASTRUCTURE_CONF_LOC}/src/main/maven/settings.xml"
fi
MAVEN_SETTINGS="${MAVEN_SETTINGS} -s ${MAVEN_SETTINGS_FILE}"
echo "MAVEN_SETTINGS: ${MAVEN_SETTINGS}"

if [ -n "${MAVEN_SETTINGS_SECURITY_FILE}" ] && [ -f "${MAVEN_SETTINGS_SECURITY_FILE}" ];then
    echo "MAVEN_SETTINGS_SECURITY_FILE: ${MAVEN_SETTINGS_SECURITY_FILE}"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dsettings.security=${MAVEN_SETTINGS_SECURITY_FILE}";
elif [ -f "${HOME}/.m2/settings-security.xml" ]; then
    echo "MAVEN_SETTINGS_SECURITY_FILE: ${HOME}/.m2/settings-security.xml"
else
    echo "MAVEN_SETTINGS_SECURITY_FILE: not found"
fi

# MAVEN_OPTS that need to be kept secret
# config jira if environment variable present
if [ -n "${BUILD_JIRA_PROJECTKEY}" ]; then
    export MAVEN_OPTS="${MAVEN_OPTS} -Djira.projectKey=${BUILD_JIRA_PROJECTKEY} -Djira.user=${BUILD_JIRA_USER} -Djira.password=${BUILD_JIRA_PASSWORD}"
fi
# public sonarqube config, see: https://sonarcloud.io
if [ "github" == "${INFRASTRUCTURE}" ]; then
    export MAVEN_OPTS="${MAVEN_OPTS} -Dsonar.organization=${SONAR_ORGANIZATION} -Dsonar.login=${SONAR_LOGIN_TOKEN}"
fi

mvn ${MAVEN_SETTINGS} -version

# log output avoid travis timeout
if [ -z "${MAVEN_EFFECTIVE_POM_FILE}" ]; then MAVEN_EFFECTIVE_POM_FILE="${BUILD_CACHE}/effective-pom-${BUILD_COMMIT_ID}.xml"; fi
echo "MAVEN_EFFECTIVE_POM_FILE: ${MAVEN_EFFECTIVE_POM_FILE}"
set +e
mvn ${MAVEN_SETTINGS} -U help:effective-pom | grep 'Downloading:' | awk '!(NR%10)'
mvn ${MAVEN_SETTINGS} help:effective-pom > ${MAVEN_EFFECTIVE_POM_FILE}
ret_val=$?
if [ ${ret_val} -ne 0 ]; then
    echo "error on generate effective-pom"
    cat ${MAVEN_EFFECTIVE_POM_FILE}
    exit 1
fi
set -e
# <<<<<<<<<< ---------- lib_maven ---------- <<<<<<<<<<

# >>>>>>>>>> ---------- lib_gradle ---------- >>>>>>>>>>
gradle_analysis() {
    echo "gradle_analysis no-op"
}

gradle_clean() {
    gradle --stacktrace ${GRADLE_PROPERTIES} clean
}

gradle_clean_except_artifacts() {
    find . -type d -wholename "**/build/classes" | xargs rm -rf
    find . -type d -wholename "**/build/docs" | xargs rm -rf
    find . -type d -wholename "**/build/jacoco" | xargs rm -rf
    find . -type d -wholename "**/build/poms" | xargs rm -rf
    find . -type d -wholename "**/build/reports" | xargs rm -rf
    find . -type d -wholename "**/build/resources" | xargs rm -rf
    find . -type d -wholename "**/build/test-results" | xargs rm -rf
    find . -type d -wholename "**/build/tmp" | xargs rm -rf
}

gradle_clean_test_and_build() {
    local signArchives=""
    if [ -f secring.gpg ] && [ -n "${GPG_KEYID}" ] && [ -n "${GPG_PASSPHRASE}" ]; then signArchives="signArchives"; fi
    if [ -f secring.gpg ] && [ -z "${GPG_KEYID}" ]; then echo "GPG_KEYID not set, use 'gpg --list-keys' to find it (Rightmost 8 hex). exit."; exit 1; fi

    gradle_clean_except_artifacts

    if [ "true" == "${BUILD_TEST_SKIP}" ]; then
        gradle --refresh-dependencies --stacktrace ${GRADLE_PROPERTIES} clean build ${signArchives} install -x test
    elif [ "true" == "${BUILD_INTEGRATION_TEST_SKIP}" ]; then
        gradle --refresh-dependencies --stacktrace ${GRADLE_PROPERTIES} clean build ${signArchives} install
    else
        gradle --refresh-dependencies --stacktrace ${GRADLE_PROPERTIES} clean build ${signArchives} integrationTest install
    fi
}

gradle_test_and_build() {
    local signArchives=""
    if [ -f secring.gpg ] && [ -n "${GPG_KEYID}" ] && [ -n "${GPG_PASSPHRASE}" ]; then signArchives="signArchives"; fi
    if [ -f secring.gpg ] && [ -z "${GPG_KEYID}" ]; then echo "GPG_KEYID not set, use 'gpg --list-keys' to find it (Rightmost 8 hex). exit."; exit 1; fi

    gradle_clean_except_artifacts

    if [ "true" == "${BUILD_TEST_SKIP}" ]; then
        gradle --refresh-dependencies --stacktrace ${GRADLE_PROPERTIES} build ${signArchives} install -x test
    elif [ "true" == "${BUILD_INTEGRATION_TEST_SKIP}" ]; then
        gradle --refresh-dependencies --stacktrace ${GRADLE_PROPERTIES} build ${signArchives} install
    else
        gradle --refresh-dependencies --stacktrace ${GRADLE_PROPERTIES} build ${signArchives} integrationTest install
    fi
}

gradle_publish_artifact() {
    gradle --stacktrace ${GRADLE_PROPERTIES} uploadArchives -x test
}

gradle_publish_site(){
    echo "gradle can't publish_site"
}

if [ -n "${GRADLE_INIT_SCRIPT}" ]; then
    if [[ "${GRADLE_INIT_SCRIPT}" == http* ]]; then
        GRADLE_INIT_SCRIPT_FILE="${BUILD_CACHE}/$(basename $(echo ${GRADLE_INIT_SCRIPT}))"
        curl -H 'Cache-Control: no-cache' -t utf-8 -s -L -o ${GRADLE_INIT_SCRIPT_FILE} ${GRADLE_INIT_SCRIPT}
        echo "curl -H 'Cache-Control: no-cache' -t utf-8 -s -L -o ${GRADLE_INIT_SCRIPT_FILE} ${GRADLE_INIT_SCRIPT}"
        export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} --init-script ${GRADLE_INIT_SCRIPT_FILE}"
    else
        export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} --init-script ${GRADLE_INIT_SCRIPT}"
    fi
fi

export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Pinfrastructure=${INFRASTRUCTURE}"
export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -PtestFailureIgnore=${BUILD_TEST_FAILURE_IGNORE}"
export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Psettings=${MAVEN_SETTINGS_FILE}"
if [ -n "${MAVEN_SETTINGS_SECURITY_FILE}" ]; then
  export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Psettings.security=${MAVEN_SETTINGS_SECURITY_FILE}"
fi
echo "GRADLE_PROPERTIES: ${GRADLE_PROPERTIES}"

gradle --stacktrace ${GRADLE_PROPERTIES} -version
# <<<<<<<<<< ---------- lib_gradle ---------- <<<<<<<<<<

analysis() {
    echo "analysis @ $(pwd)";
    if [ -f pom.xml ]; then maven_analysis; fi
}

clean() {
    echo "clean @ $(pwd)";
    if [ -f pom.xml ]; then maven_clean; fi
    if [ -f build.gradle ]; then gradle_clean; fi
}

clean_test_and_build() {
    echo "clean @ $(pwd)";
    if [ -f pom.xml ]; then maven_clean_test_and_build; fi
    if [ -f build.gradle ]; then gradle_clean_test_and_build; fi
}

test_and_build() {
    echo "test_and_build @ $(pwd)";
    if [ -f pom.xml ]; then maven_test_and_build; fi
    if [ -f build.gradle ]; then gradle_test_and_build; fi
}

publish_artifact() {
    echo "publish @ $(pwd)";
    if [ -f pom.xml ]; then maven_publish_artifact; fi
    if [ -f build.gradle ]; then gradle_publish_artifact; fi
}

publish_site(){
    echo "publish_site @ $(pwd)";
    if [ -f pom.xml ]; then maven_publish_site; fi
}

# main

if [ -z "${ORIGIN_REPO_SLUG}" ]; then ORIGIN_REPO_SLUG="unknown/unknown"; fi
echo "ORIGIN_REPO_SLUG: ${ORIGIN_REPO_SLUG}"
CURRENT_REPO_SLUG=$(git_repo_slug)
echo "CURRENT_REPO_SLUG: ${CURRENT_REPO_SLUG}"
IS_ON_ORIGIN_REPO="false"
if ([ "${CURRENT_REPO_SLUG}" == "${ORIGIN_REPO_SLUG}" ] && [ "pull_request" != "${TRAVIS_EVENT_TYPE}" ]); then IS_ON_ORIGIN_REPO="true"; fi
echo "IS_ON_ORIGIN_REPO: ${IS_ON_ORIGIN_REPO}"


# arguments: is_on_origin_repo, build_ref_name, cmd
function whether_perform_command() {
    local is_on_origin_repo="${1}"
    local build_ref_name="${2}"
    local cmd="${3}"

    if [[ "${cmd}" == *publish_site ]]; then
        if [ "true" == "${BUILD_SITE}" ]; then
            return
        fi
    elif ([[ "${cmd}" == *test_and_build ]] || [[ "${cmd}" == *clean ]]); then
        return
    elif [ "true" == "${is_on_origin_repo}" ]; then
        case "${build_ref_name}" in
            "develop")
                return
                ;;
            release*)
                if [[ "${cmd}" != *analysis ]]; then
                    return
                fi
                ;;
            feature*|hotfix*|"master"|*)
                if ([[ "${cmd}" == *test_and_build ]] || [[ "${cmd}" == *clean ]]); then
                    return
                fi
                ;;
        esac
    fi

    false
}

if [ -z "${BUILD_SKIP_COMMANDS_EXECUTION}" ] || [ "${BUILD_SKIP_COMMANDS_EXECUTION}" == "false" ]; then
    export COMMANDS_SKIPPED=()
    export COMMANDS_WILL_PERFORM=()
    for element in $@; do
        echo "Test command: '${element}'"
        if whether_perform_command "${IS_ON_ORIGIN_REPO}" "${BUILD_REF_NAME}" "${element}"; then
            COMMANDS_WILL_PERFORM+=("${element}")
        else
            echo "Skip ${element} on IS_ON_ORIGIN_REPO: '${IS_ON_ORIGIN_REPO}' BUILD_REF_NAME: '${BUILD_REF_NAME}'"
            COMMANDS_SKIPPED+=("${element}")
        fi
    done
    echo "COMMANDS: '$@'"
    echo "COMMANDS_SKIPPED: '${COMMANDS_SKIPPED[@]}'"
    echo "COMMANDS_WILL_PERFORM: '${COMMANDS_WILL_PERFORM[@]}'"

    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> execute '${COMMANDS_WILL_PERFORM[@]}' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    for command in ${COMMANDS_WILL_PERFORM[@]}; do
        echo ">>>>>>>>>>>>>>>>>>>> execute '${command}' >>>>>>>>>>>>>>>>>>>>"
        ${command}
        echo "<<<<<<<<<<<<<<<<<<<< done '${command}' <<<<<<<<<<<<<<<<<<<<"
    done
    echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< done '${COMMANDS_WILL_PERFORM[@]}' <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
else
    echo "SKIP_COMMANDS_EXECUTION"
fi

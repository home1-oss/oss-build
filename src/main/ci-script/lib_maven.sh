#!/usr/bin/env bash

set -e

if [ ! -f "src/main/ci-script/maven_opts_${INFRASTRUCTURE}.sh" ]; then
    echo "eval \$(curl -H 'Cache-Control: no-cache' -H \"PRIVATE-TOKEN: \${GIT_SERVICE_TOKEN}\" -s -L ${BUILD_CONFIG_LOC}/src/main/maven/maven_opts_${INFRASTRUCTURE}.sh)"
    eval "$(curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${GIT_SERVICE_TOKEN}" -s -L ${BUILD_CONFIG_LOC}/src/main/maven/maven_opts_${INFRASTRUCTURE}.sh)"
else
    . src/main/ci-script/maven_opts_${INFRASTRUCTURE}.sh
fi

if [ ! -f "$(pwd)/src/main/maven/settings-${INFRASTRUCTURE}.xml" ]; then
    MAVEN_SETTINGS_FILE="${CI_CACHE}/settings-${INFRASTRUCTURE}-${COMMIT_ID}.xml"
    curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${GIT_SERVICE_TOKEN}" -t utf-8 -s -L -o ${MAVEN_SETTINGS_FILE} ${BUILD_CONFIG_LOC}/src/main/maven/settings-${INFRASTRUCTURE}.xml
    export MAVEN_SETTINGS="${MAVEN_SETTINGS} -s ${MAVEN_SETTINGS_FILE}"
else
    export MAVEN_SETTINGS="${MAVEN_SETTINGS} -s $(pwd)/src/main/maven/settings-${INFRASTRUCTURE}.xml"
fi

# offline ,should download file in ci.sh or other way
if [ -n "${MAVEN_SETTINGS_SECURITY_FILE}" ] && [ -f "${MAVEN_SETTINGS_SECURITY_FILE}" ];then
    export MAVEN_OPTS="${MAVEN_OPTS} -Dsettings.security=${MAVEN_SETTINGS_SECURITY_FILE}";
fi

if [ -n "${BUILD_JIRA_PROJECTKEY}" ]; then
    export MAVEN_OPTS="${MAVEN_OPTS} -Djira.projectKey=${BUILD_JIRA_PROJECTKEY} -Djira.user=${BUILD_JIRA_USER} -Djira.password=${BUILD_JIRA_PASSWORD}"
fi

mvn ${MAVEN_SETTINGS} -version
EFFECTIVE_POM_FILE="${CI_CACHE}/effective-pom-${COMMIT_ID}.xml"

# 本地Repo临时地址，后续发布会从此目录deploy到远程仓库
DEPLOY_LOCAL_REPO_IF_NEED="${HOME}/local-deploy/${COMMIT_ID}"
if [ ! -d "${DEPLOY_LOCAL_REPO_IF_NEED}" ]; then mkdir -p ${DEPLOY_LOCAL_REPO_IF_NEED}; fi

echo "maven_settings: ${MAVEN_SETTINGS} effective-pom: ${EFFECTIVE_POM_FILE}"
# log output avoid travis timeout
mvn ${MAVEN_SETTINGS} help:effective-pom | grep 'Downloading:' | awk '!(NR%10)'
mvn ${MAVEN_SETTINGS} help:effective-pom > ${EFFECTIVE_POM_FILE}

export LOGGING_LEVEL_="INFO"
echo "LOGGING_LEVEL_: ${LOGGING_LEVEL_}"

maven_pull_base_images() {
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
    export MAVEN_OPTS="${MAVEN_OPTS} -Dsonar.organization=${SONAR_ORGANIZATION}"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dsonar.login=${SONAR_LOGIN_TOKEN}"

    if [[ "$(basename $(pwd))" == *-config ]] && ([ -f "application.yml" ] || [ -f "application.properties" ]); then
        echo "maven_analysis config repository"
        mvn ${MAVEN_SETTINGS} -U clean package | grep -v 'Downloading:' | grep -Ev '^Generating .+\.html\.\.\.'
    else
        echo "maven_analysis sonar"
        mvn ${MAVEN_SETTINGS} sonar:sonar
    fi
}

maven_test_and_build() {
    # 构建阶段的docker build不会执行，因为插件绑定的生命周期是通过开关控制的，BUILD_PUBLISH_DEPLOY_SEGREGATION
    # 具体参照 oss-build/pom.xml中定义的profile: build-push-segregation-with-docker
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.skip=${BUILD_TEST_SKIP}"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.integration-test.skip=${BUILD_TEST_SKIP}"

    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.source.filepath=${DEPLOY_LOCAL_REPO_IF_NEED} -Dactive_publish_segregation=true"
        export MAVEN_OPTS="${MAVEN_OPTS} -DaltDeploymentRepository=repo::default::file://${DEPLOY_LOCAL_REPO_IF_NEED}"

        echo "maven_test_and_build EFFECTIVE_POM_FILE: ${EFFECTIVE_POM_FILE}"
        echo "maven_test_and_build MAVEN_OPTS: ${MAVEN_OPTS}"

        maven_pull_base_images
        # reduce log avoid travis 4MB limit
        mvn ${MAVEN_SETTINGS} -U clean org.apache.maven.plugins:maven-antrun-plugin:run@clean-local-deploy-dir deploy | grep -v 'Downloading:' | grep -Ev '^Generating .+\.html\.\.\.'
    else
        maven_pull_base_images
        # reduce log avoid travis 4MB limit
        mvn ${MAVEN_SETTINGS} -U clean install | grep -v 'Downloading:' | grep -Ev '^Generating .+\.html\.\.\.'
    fi
}

maven_publish_snapshot() {
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.clean.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.integration-test.skip=true"
    mvn ${MAVEN_SETTINGS} help:active-profiles
    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.source.filepath=${DEPLOY_LOCAL_REPO_IF_NEED} -Dactive_publish_segregation=true"
        export MAVEN_OPTS="${MAVEN_OPTS} -DaltDeploymentRepository=repo::default::file://${DEPLOY_LOCAL_REPO_IF_NEED}"
        export MAVEN_OPTS="${MAVEN_OPTS} -Dbuild.publish.channel=${BUILD_PUBLISH_CHANNEL}"
        if [ "github" == "${INFRASTRUCTURE}" ]; then
            export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.merge-maven-repos.target=${NEXUS_SNAPSHOT_DISTRIBUTE_URL}"
            export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.merge-maven-repos.targetId=github-nexus-snapshots"
        fi
        echo "maven_publish_snapshot: MAVEN_OPTS: ${MAVEN_OPTS}"
        mvn ${MAVEN_SETTINGS} org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@deploy-merge-maven-repos docker:build docker:push
    else
        mvn ${MAVEN_SETTINGS} deploy
    fi

}

maven_publish_release() {
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.clean.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.integration-test.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Ddependency-check=${BUILD_DEPENDENCY_CHECK}"

    if [ "true" == "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then
        export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.source.filepath=${DEPLOY_LOCAL_REPO_IF_NEED} -Dactive_publish_segregation=true"
        export MAVEN_OPTS="${MAVEN_OPTS} -DaltDeploymentRepository=repo::default::file://${DEPLOY_LOCAL_REPO_IF_NEED}"
        export MAVEN_OPTS="${MAVEN_OPTS} -Dbuild.publish.channel=${BUILD_PUBLISH_CHANNEL}"
        if [ "github" == "${INFRASTRUCTURE}" ]; then
            export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.merge-maven-repos.target=${NEXUS_RELEASE_DISTRIBUTE_URL}"
            export MAVEN_OPTS="${MAVEN_OPTS} -Dwagon.merge-maven-repos.targetId=github-nexus-releases"
        fi
        echo "maven_publish_snapshot: MAVEN_OPTS: ${MAVEN_OPTS}"
        mvn ${MAVEN_SETTINGS} org.codehaus.mojo:wagon-maven-plugin:merge-maven-repos@deploy-merge-maven-repos docker:build docker:push
    else
        mvn ${MAVEN_SETTINGS} deploy
    fi
}

maven_publish_maven_site(){
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.clean.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.test.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.integration-test.skip=true"
    export MAVEN_OPTS="${MAVEN_OPTS} -Ddependency-check=${BUILD_DEPENDENCY_CHECK}"

    # 先 deploy 才能构建site
    if [ "true" == "${BUILD_SITE}" ]; then
        if [ ! -z "${BUILD_SITE_PATH_PREFIX}" ]; then
            export MAVEN_OPTS="${MAVEN_OPTS} -Dsite.path=${BUILD_SITE_PATH_PREFIX}-${BUILD_PUBLISH_CHANNEL}"
        fi
        if [ "${INFRASTRUCTURE}" != "github" ]; then
            echo yes | mvn ${MAVEN_SETTINGS} site:site site:stage site:stage-deploy | grep -v 'Downloading:' | grep -Ev '^Generating .+\.html\.\.\.'
        else
            # -X enable debug logging for Maven to avoid build timeout (not generate output)
            mvn ${MAVEN_SETTINGS} site site-deploy | grep -v 'Downloading:' | grep -Ev '^Generating .+\.html\.\.\.'
        fi
    fi
}

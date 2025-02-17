# Makefile to build the SDK repository packages.

.PHONY: sdk_repo

SDK_REPO_DEPS       :=
SDK_REPO_XML_ARGS   :=
SDK_EXTRAS_DEPS     :=
SDK_EXTRAS_XML_ARGS :=
SDK_SYSIMG_DEPS     :=
SDK_SYSIMG_XML_ARGS :=

# Define the name of a package zip file to generate
# $1=OS (e.g. linux, darwin)
# $2=sdk zip (e.g. out/host/linux.../android-eng-sdk.zip)
# $3=package to create (e.g. tools, docs, etc.)
#
define sdk-repo-pkg-zip
$(dir $(2))/sdk-repo-$(1)-$(3).zip
endef

# Defines the rule to build an SDK repository package by zipping all
# the content of the given directory.
# E.g. given a folder out/host/linux.../sdk/android-eng-sdk/tools
# this generates an sdk-repo-linux-tools that contains tools/*
#
# $1=variable where to accumulate args for mk_sdk_repo_xml.
# $2=OS (e.g. linux, darwin)
# $3=sdk zip (e.g. out/host/linux.../android-eng-sdk.zip)
# $4=package to create (e.g. tools, docs, etc.)
#
# The rule depends on the SDK zip file, which is defined by $2.
#
define mk-sdk-repo-pkg-1
$(call sdk-repo-pkg-zip,$(2),$(3),$(4)): $(3)
	@echo "Building SDK repository package $(4) from $(notdir $(3))"
	$(hide) rm -f $$@ && \
	        $(SOONG_ZIP) -o $$@ -C $(basename $(3)) -D $(basename $(3))/$(4)
$(call dist-for-goals-with-filenametag, sdk_repo, $(call sdk-repo-pkg-zip,$(2),$(3),$(4)))
$(1) += $(4) $(2) \
    $(call sdk-repo-pkg-zip,$(2),$(3),$(4)):$(notdir $(call sdk-repo-pkg-zip,$(2),$(3),$(4)))

$(call declare-1p-container,$(call sdk-repo-pkg-zip,$(2),$(3),$(4)),sdk_repo)
$(call declare-container-license-deps,$(call sdk-repo-pkg-zip,$(2),$(3),$(4)),$(3),$(PRODUCT_OUT)/:/)
endef

# Defines the rule to build an SDK repository package when the
# package directory contains a single platform-related inner directory.
# E.g. given a folder out/host/linux.../sdk/android-eng-sdk/samples/android-N
# this generates an sdk-repo-linux-samples that contains android-N/*
#
# $1=variable where to accumulate args for mk_sdk_repo_xml.
# $2=OS (e.g. linux, darwin)
# $3=sdk zip (e.g. out/host/linux.../android-eng-sdk.zip)
# $4=package to create (e.g. platforms, samples, etc.)
#
# The rule depends on the SDK zip file, which is defined by $2.
#
define mk-sdk-repo-pkg-2
$(call sdk-repo-pkg-zip,$(2),$(3),$(4)): $(3)
	@echo "Building SDK repository package $(4) from $(notdir $(3))"
	$(hide) rm -f $$@ && \
	        $(SOONG_ZIP) -o $$@ -C $(basename $(3))/$(4) -D $(basename $(3))/$(4)
$(call dist-for-goals-with-filenametag, sdk_repo, $(call sdk-repo-pkg-zip,$(2),$(3),$(4)))
$(1) += $(4) $(2) \
    $(call sdk-repo-pkg-zip,$(2),$(3),$(4)):$(notdir $(call sdk-repo-pkg-zip,$(2),$(3),$(4)))

$(call declare-1p-container,$(call sdk-repo-pkg-zip,$(2),$(3),$(4)),sdk_repo)
$(call declare-container-license-deps,$(call sdk-repo-pkg-zip,$(2),$(3),$(4)),$(3),$(PRODUCT_OUT)/:/)
endef

# Defines the rule to build an SDK sources package.
#
# $1=variable where to accumulate args for mk_sdk_repo_xml.
# $2=OS (e.g. linux, darwin)
# $3=sdk zip (e.g. out/host/linux.../android-eng-sdk.zip)
# $4=package to create, must be "sources"
#
define mk-sdk-repo-sources
bcp_srcjar := $(call intermediates-dir-for,ETC,platform-bootclasspath.srcjar)/platform-bootclasspath.srcjar
source_props := $(HOST_OUT)/development/sdk/source_source.properties
$(call sdk-repo-pkg-zip,$(2),$(3),$(4)): $(3) $$(bcp_srcjar) $$(source_props)
	@echo "Building SDK sources package"
	unzip -qd $(dir $$@)/tmp $$(bcp_srcjar)
	$$(SOONG_ZIP) -o $$@ -P src -e source.properties -f $$(source_props) -C $(dir $$@)/tmp -D $(dir $$@)/tmp
	rm -r $(dir $$@)/tmp
$(call dist-for-goals-with-filenametag, sdk_repo, $(call sdk-repo-pkg-zip,$(2),$(3),$(4)))
$(1) += $(4) $(2) \
    $(call sdk-repo-pkg-zip,$(2),$(3),$(4)):$(notdir $(call sdk-repo-pkg-zip,$(2),$(3),$(4)))

$(call declare-1p-container,$(call sdk-repo-pkg-zip,$(2),$(3),$(4)),sdk_repo)
$(call declare-container-license-deps,$(call sdk-repo-pkg-zip,$(2),$(3),$(4)),$(3) $(HOST_OUT)/development/sdk/source_source.properties,$(PRODUCT_OUT)/:/)
endef

# Defines the rule to build an XML file for a package.
#
# $1=output file
# $2=schema file
# $3=deps
# $4=args
define mk-sdk-repo-xml
$(1): $$(XMLLINT) development/build/tools/mk_sdk_repo_xml.sh $(2) $(3)
	XMLLINT=$$(XMLLINT) development/build/tools/mk_sdk_repo_xml.sh $$@ $(2) $(4)

$$(call dist-for-goals,sdk_repo,$(1))

$(call declare-1p-target,$(1),sdk_repo)
$(call declare-container-license-deps,$(1),$(2) $(3),$(PRODUCT_OUT)/:/)
endef

# -----------------------------------------------------------------
# Rules for main host sdk

ifneq ($(filter sdk,$(MAKECMDGOALS)),)

# All these go in the main repository.xml
$(eval $(call mk-sdk-repo-pkg-1,SDK_REPO_XML_ARGS,$(HOST_OS),$(MAIN_SDK_ZIP),docs))
$(eval $(call mk-sdk-repo-pkg-2,SDK_REPO_XML_ARGS,$(HOST_OS),$(MAIN_SDK_ZIP),platforms))
$(eval $(call mk-sdk-repo-pkg-2,SDK_REPO_XML_ARGS,$(HOST_OS),$(MAIN_SDK_ZIP),samples))
$(eval $(call mk-sdk-repo-sources,SDK_REPO_XML_ARGS,$(HOST_OS),$(MAIN_SDK_ZIP),sources))

SDK_REPO_DEPS += \
    $(call sdk-repo-pkg-zip,$(HOST_OS),$(MAIN_SDK_ZIP),docs) \
    $(call sdk-repo-pkg-zip,$(HOST_OS),$(MAIN_SDK_ZIP),platforms) \
    $(call sdk-repo-pkg-zip,$(HOST_OS),$(MAIN_SDK_ZIP),samples) \
    $(call sdk-repo-pkg-zip,$(HOST_OS),$(MAIN_SDK_ZIP),sources)

endif

# -----------------------------------------------------------------
# Pickup the most recent xml schema for repository and add-on

SDK_REPO_XSD := \
    $(lastword \
      $(wildcard \
        prebuilts/devtools/repository/sdk-repository-*.xsd \
    ))

SDK_ADDON_XSD := \
    $(lastword \
      $(wildcard \
        prebuilts/devtools/repository/sdk-addon-*.xsd \
    ))

SDK_SYSIMG_XSD := \
    $(lastword \
      $(wildcard \
        prebuilts/devtools/repository/sdk-sys-img-*.xsd \
    ))


# -----------------------------------------------------------------
# Rules for sdk addon

ifneq ($(filter sdk_addon,$(MAKECMDGOALS)),)
ifneq ($(ADDON_SDK_ZIP),)

# ADDON_SDK_ZIP is defined in build/core/tasks/sdk-addon.sh and is
# already packaged correctly. All we have to do is dist it with
# a different destination name.

RENAMED_ADDON_ZIP := $(ADDON_SDK_ZIP):$(notdir $(call sdk-repo-pkg-zip,$(HOST_OS),$(ADDON_SDK_ZIP),addon))

$(call dist-for-goals, sdk_repo, $(RENAMED_ADDON_ZIP))

# Also generate the addon.xml using the latest schema and the renamed addon zip

SDK_ADDON_XML := $(dir $(ADDON_SDK_ZIP))/addon.xml

$(eval $(call mk-sdk-repo-xml,$(SDK_ADDON_XML),$(SDK_ADDON_XSD),$(ADDON_SDK_ZIP),add-on $(HOST_OS) $(RENAMED_ADDON_ZIP)))

SDK_ADDON_XML :=
RENAMED_ADDON_ZIP :=

endif

ifneq ($(ADDON_SDK_IMG_ZIP),)

# Copy/rename the ADDON_SDK_IMG_ZIP file as an sdk-repo zip in the dist dir

RENAMED_ADDON_IMG_ZIP := $(ADDON_SDK_IMG_ZIP):$(notdir $(call sdk-repo-pkg-zip,$(HOST_OS),$(ADDON_SDK_IMG_ZIP),system-images))

$(call dist-for-goals, sdk_repo, $(RENAMED_ADDON_IMG_ZIP))

# Generate the system-image XML for the addon sys-img

SDK_ADDON_IMG_XML := $(dir $(ADDON_SDK_ZIP))/addon-sys-img.xml

$(eval $(call mk-sdk-repo-xml,$(SDK_ADDON_IMG_XML),$(SDK_SYSIMG_XSD),$(ADDON_SDK_IMG_ZIP),system-image $(HOST_OS) $(RENAMED_ADDON_IMG_ZIP)))

SDK_ADDON_IMG_XML :=
RENAMED_ADDON_IMG_ZIP :=

endif
endif

# -----------------------------------------------------------------
# Rules for the SDK Repository XML

SDK_REPO_XML   := $(MAIN_SDK_DIR)/repository.xml
SDK_EXTRAS_XML := $(MAIN_SDK_DIR)/repo-extras.xml
SDK_SYSIMG_XML := $(MAIN_SDK_DIR)/repo-sys-img.xml

ifneq ($(SDK_REPO_XML_ARGS),)
$(eval $(call mk-sdk-repo-xml,$(SDK_REPO_XML),$(SDK_REPO_XSD),$(SDK_REPO_DEPS),$(SDK_REPO_XML_ARGS)))
else
SDK_REPO_XML :=
endif


ifneq ($(SDK_EXTRAS_XML_ARGS),)
$(eval $(call mk-sdk-repo-xml,$(SDK_EXTRAS_XML),$(SDK_ADDON_XSD),$(SDK_EXTRAS_DEPS),$(SDK_EXTRAS_XML_ARGS)))
else
SDK_EXTRAS_XML :=
endif


ifneq ($(SDK_SYSIMG_XML_ARGS),)
$(eval $(call mk-sdk-repo-xml,$(SDK_SYSIMG_XML),$(SDK_SYSIMG_XSD),$(SDK_SYSIMG_DEPS),$(SDK_SYSIMG_XML_ARGS)))
else
SDK_SYSIMG_XML :=
endif

# -----------------------------------------------------------------

sdk_repo: $(SDK_REPO_DEPS) $(SDK_REPO_XML) $(SDK_EXTRAS_XML) $(SDK_SYSIMG_XML)

SDK_REPO_DEPS :=
SDK_REPO_XML :=
SDK_REPO_XML_ARGS :=
SDK_EXTRAS_DEPS :=
SDK_EXTRAS_XML :=
SDK_EXTRAS_XML_ARGS :=
SDK_SYSIMG_DEPS :=
SDK_SYSIMG_XML :=
SDK_SYSIMG_XML_ARGS :=

mk-sdk-repo-pkg-1 :=
mk-sdk-repo-pkg-2 :=
mk-sdk-repo-sources :=
mk-sdk-repo-xml :=
sdk-repo-pkg-zip :=

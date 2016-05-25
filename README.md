dans-parent
===========

DANS Parent POM and supporting resources. DANS Maven projects should use ``dans-prototype`` as their parent project (directly or
indirectly), like this (be sure to use the latest version):

    <parent>
        <groupId>nl.knaw.dans.shared</groupId>
        <artifactId>dans-prototype</artifactId>
        <version>1.11</version>
    </parent>

Test

Install
=======

If you have access to ``maven-repo.dans.knaw.nl``, the DANS internal repository, you do not need to do anything else to use
``dans-parent``. Otherwise, you will need to clone and install it in you local maven cache with:

    mvn clean install


Use
===

``dans-parent`` is mainly used to for dependency and plug-in management. It adds only a couple of dependencies and plug-ins
by default (see the ``dans-prototype`` pom file for details). Other dependencies and plug-ins can be added in a simplified
way because the version can be left out. In the case of standard maven plug-ins even the groupId can be left out.

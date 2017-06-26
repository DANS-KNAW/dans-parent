package nl.knaw.dans.build;

import org.junit.Before;
import org.junit.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.nio.file.Paths;

import static org.junit.Assert.assertEquals;

public class GenerateRpmScriptsTest {

  private Path scriptsDir = Paths.get("src/test/resources/scripts");
  private Path includesDir = Paths.get("src/test/resources/includes");
  private Path targetDir = Paths.get("target/test/", getClass().getSimpleName());
  private Path expectedOutputsDir = Paths.get("src/test/resources/expectedOutputs");

  private String readFileToString(Path p) throws IOException {
    return new String(Files.readAllBytes(p), StandardCharsets.UTF_8);
  }

  private void assertFilesEqual(Path expected, Path actual) throws IOException {
    String expectedText = readFileToString(expected);
    String actualText = readFileToString(actual);
    assertEquals(expectedText, actualText);
  }

  @Before public void setUp() throws IOException {
    Files.createDirectories(targetDir);
  }

  @Test public void emptyScriptShouldStayTheSame() throws Exception {
    final String FILENAME = "DOES-NOT-EXIST.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertEquals(0L, Files.size(targetDir.resolve(FILENAME)));
  }

  @Test public void emptyIncludeShouldOnyRemoveIncludeDirective() throws Exception {
    final String FILENAME = "empty-include.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test(expected = NoSuchFileException.class)
  public void nonExistentIncludeShouldResultInFileNotFoundException() throws Exception {
    final String FILENAME = "include-not-found.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
  }

  @Test public void multiIncludeShouldIncludeInOrder() throws Exception {
    final String FILENAME = "multi-include-consecutive.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test public void multiIncludeDistributedShouldLeaveTextBetweenIncludesInPlace() throws Exception {
    final String FILENAME = "multi-include-distributed.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test public void scriptWithNoIncludesShouldStayTheSame() throws Exception {
    final String FILENAME = "no-includes.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(scriptsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test public void includeAtEnd() throws Exception {
    final String FILENAME = "one-include-end.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test public void includeInMiddle() throws Exception {
    final String FILENAME = "one-include-middle.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test public void includeStart() throws Exception {
    final String FILENAME = "one-include-start.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }

  @Test public void nonExistentScriptResultsInEmptyResult() throws Exception {
    final String FILENAME = "DOES-NOT-EXIST.txt";
    GenerateRpmScripts.execute(scriptsDir.resolve(FILENAME), includesDir, targetDir);
    assertFilesEqual(expectedOutputsDir.resolve(FILENAME), targetDir.resolve(FILENAME));
  }
}

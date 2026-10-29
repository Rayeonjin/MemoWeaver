# Source availability for third-party components

The following components retain their upstream licenses. They are separate
from MemoWeaver's project-owned Apache-2.0 code. MemoWeaver does not replace
or restrict rights that those upstream licenses grant.

## EPL-2.0: elkjs 0.9.3 / Eclipse Layout Kernel

The component's source is available from these public, versioned upstream
locations in the same customary electronic medium as this distribution:

- elkjs exact release source and build files:
  https://github.com/kieler/elkjs/tree/a8304cf79fde75bc2ab1a89d28320f53f8637436
- Downloadable elkjs source:
  https://github.com/kieler/elkjs/archive/a8304cf79fde75bc2ab1a89d28320f53f8637436.tar.gz
- Upstream release declaration (ELK 0.9.1 with additional PR 955):
  https://github.com/kieler/elkjs/releases/tag/0.9.3
- ELK 0.9.1 base source:
  https://github.com/eclipse-elk/elk/tree/62d5909f96fad541bc101ad52dabaece6b7eab7e
- Additional upstream patch and merge commit:
  https://github.com/eclipse-elk/elk/pull/955
  https://github.com/eclipse-elk/elk/commit/7ca51784e42a24201f29bc13e458728b6fc61cdc

Use the accompanying EPL-2.0 text and ELK NOTICE. MemoWeaver retains the
upstream algorithm payload; bundling/minification and the local app bridge are
identified in the audit report. The original GWT build receipt is not available;
these source references follow the original maintainer's release declaration.

## EPL-1.0 / EPL-2.0 and Apache-2.0: Java-to-JavaScript dependencies

ELK's build.gradle identifies the following source inputs. They are included
conservatively as source/notice coverage; no claim is made that every Java
class survives GWT optimization. The listed source archives were downloaded
and checksum-verified during the audit. Their copyrights and license headers
are preserved under maven/ and supplemental/. Source remains available under
the applicable original license, including the EPL component terms.

- com.google.guava:guava:31.1-jre (Apache-2.0)
  https://repo.maven.apache.org/maven2/com/google/guava/guava/31.1-jre/guava-31.1-jre-sources.jar
  SHA-256: 8ab1853cdaf936ec88be80c17302b7c20abafbd4f54d4fb54d7011c529e3a44a
- com.google.guava:guava-gwt:31.1-jre (Apache-2.0)
  https://repo.maven.apache.org/maven2/com/google/guava/guava-gwt/31.1-jre/guava-gwt-31.1-jre-sources.jar
  SHA-256: d7e52f41ac6ea010787b5b3c8db7ffb54375d8d0c39c98c2badc9c38de7bf14b
- org.gwtproject:gwt-user:2.10.0 (Apache-2.0)
  https://repo.maven.apache.org/maven2/org/gwtproject/gwt-user/2.10.0/gwt-user-2.10.0-sources.jar
  SHA-256: 731ff22188418a1dfaca30c8956ea107e87219ba7c4fb32d2f059ede317660b9
- org.gwtproject:gwt-dev:2.10.0 (Apache-2.0)
  https://repo.maven.apache.org/maven2/org/gwtproject/gwt-dev/2.10.0/gwt-dev-2.10.0-sources.jar
  SHA-256: a6fa83d53ea164c26556d791369391d25280a92f5d19657eeb0c865a9af2a097
- com.genmymodel.emf.gwt:emf-common:2.12.4 (EPL-1.0)
  https://repo.maven.apache.org/maven2/com/genmymodel/emf/gwt/emf-common/2.12.4/emf-common-2.12.4-sources.jar
  SHA-256: 8dfc4e97ca8eee5474927e2b0c5f3bdbd9a52dcd5dff8c0b433b1e938b843bbe
- com.genmymodel.emf.gwt:emf-ecore:2.12.4 (EPL-1.0)
  https://repo.maven.apache.org/maven2/com/genmymodel/emf/gwt/emf-ecore/2.12.4/emf-ecore-2.12.4-sources.jar
  SHA-256: dd3b8c1c3bd0a27c1fbba908bcf0ff21a999148da4e68b3546bcde1dbce7b13a
- org.eclipse.xtend:org.eclipse.xtend.lib:2.28.0 (EPL-2.0)
  https://repo.maven.apache.org/maven2/org/eclipse/xtend/org.eclipse.xtend.lib/2.28.0/org.eclipse.xtend.lib-2.28.0-sources.jar
  SHA-256: 899f1ffb8d761f11bb5f7b74e46cdd790bd8f9bc398221cd62524eea9344d926
- org.eclipse.xtext:org.eclipse.xtext.xbase.lib:2.28.0 (EPL-2.0)
  https://repo.maven.apache.org/maven2/org/eclipse/xtext/org.eclipse.xtext.xbase.lib/2.28.0/org.eclipse.xtext.xbase.lib-2.28.0-sources.jar
  SHA-256: 2b35e9ccd4308f605e213371bb26f458b6a84bbd1e3a13cecaac0eba607db69f

## Other upstream JavaScript sources and modifications

manifest.json records official npm source archives, integrity digests and git
revisions for each package/version. These npm packages include the distributable
source, prebuilt code and, where supplied, source maps with sourcesContent.
Mermaid's published source maps also identify upstream patched fastdom/roughjs
inputs. Their retained prebuilt code is not silently replaced by this audit.
The checked-in reconstruction and AST comparison are audit evidence; they are
not presented as the missing original producer's build receipt.

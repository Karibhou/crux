package runtime

import (
	"io"
	"os"

	"github.com/hivecommons/crux/cline"
)

// RunClineTurn runs one bounded official Cline CLI task inside an agent pane.
func RunClineTurn(args []string, stdout, stderr io.Writer) int {
	return cline.Run(args, os.Stdin, stdout, stderr)
}

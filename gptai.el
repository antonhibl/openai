;;; gptai.el --- Integrate with the OpenAI API -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Hibl, Anton

;; Author: Anton Hibl <antonhibl11@gmail.com>
;; URL: https://github.com/antonhibl/gptai
;; Keywords: comm, convenience
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This is intended to allow for development and programming queries into the
;; OpenAI API.  This allows for sending queries stright from Emacs directly into
;; various models of OpenAI's platform.

;; See the accompanying Readme.org for configuration details.

;;; Code:

;;; Customization
(defgroup gptai nil
  "Use the openAI API."
  :prefix "gptai-"
  :group 'comm
  :link '(url-link :tag "Repository" "https://github.com/antonhibl/gptai"))

;; dependencies
(require 'url)
(require 'json)

;; default values for local variables
(defvar gptai-base-url "https://api.openai.com/v1/completions")
(defvar gptai-model nil)
(defvar gptai-api-key nil)
(defvar url-http-end-of-headers)

;; parse prompt into a request for the openai API
(defun gptai-request (gptai-prompt)
  "Sends a request to OpenAI API and return the response.
Argument GPTAI-PROMPT prompt."
  (when (null gptai-api-key)
    (error "OpenAI API key is not set"))
  (let* ((url-request-method "POST")
         (url-request-extra-headers
          `(("Content-Type" . "application/json")
            ("Authorization" . ,(format "Bearer %s" gptai-api-key))))
         (url-request-data
          (json-encode `(("model" . ,gptai-model)
                         ("prompt" . ,gptai-prompt)
                         ("temperature" . 0.7)
                         ("max_tokens" . 1000)))))
    (message "Sending request to OpenAI API using model '%s'" gptai-model)
    (condition-case gptai-err
        (with-current-buffer
            (url-retrieve-synchronously gptai-base-url nil 'silent)
          (goto-char url-http-end-of-headers)
          (let ((response (json-read)))
            (when (assoc 'error response)
              (error (cdr (assoc 'message (cdr (assoc 'error response))))))
            response))
      (error (error "Error while sending request to OpenAI API: %s"
                    (error-message-string gptai-err))))))

;; send query simple
(defun gptai-send-query (gptai-prompt)
  "Sends a query to OpenAI API and insert the response text at the current point.
Argument GPTAI-PROMPT prompt."
  (interactive
   (list (read-string "Prompt: ")))
  (let ((response (gptai-request gptai-prompt)))
    (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
      (if text
          (insert text)
        (error
         "Response doesn't contain text data")))))

;; send query from selections
(defun gptai-send-query-from-selection ()
  "Sends query to OpenAI API using selected text, replace selection w/ resp."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                          (buffer-substring-no-properties
                           (region-beginning)
                           (region-end))
                        (read-string "Query: "))))
    (let ((response (gptai-request gptai-prompt)))
      (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
        (delete-region (region-beginning)
                       (region-end))
        (insert text)))))

;; send query from buffer
(defun gptai-send-query-from-buffer (&optional buffer-name)
  "Sends a query to OpenAI API using the buffer as a prompt.
Optional argument BUFFER-NAME buffer to send."
  (interactive
   (list (read-buffer "Buffer: " (current-buffer))))
  (let ((gptai-prompt (with-current-buffer buffer-name
                        (buffer-substring
                         (point-min)
                         (point-max)))))
    (let ((response (gptai-request gptai-prompt)))
      (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response))
                                         0)))))
        (with-current-buffer buffer-name
          (erase-buffer)
          (insert text)
          (display-buffer (current-buffer) t))))))

;; spellcheck selection in place with openGPT
(defun gptai-spellcheck-text-from-selection ()
  "Sends query to OpenAI API to spellcheck the selection region."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Text: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "Spellcheck this text: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text))))))

;; elaborate on text from selection in place with openGPT
(defun gptai-elaborate-on-text-from-selection ()
  "Sends query to OpenAI API to elaborate on the selection region."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Text: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "Elaborate on this text: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text))))))

;; code generation query, prompts for instructions and language
(defun gptai-code-query-from-selection (gptai-instructions gptai-language)
  "Sends instructions to OpenAI API to code in a language.
Argument GPTAI-INSTRUCTIONS code instructions for query.
Argument GPTAI-LANGUAGE language to generate."
  (interactive
   (list (read-string "Instructions: ")
         (read-string "Language: ")))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "%s(%s)" gptai-instructions gptai-language))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text)))))

;; code generation query, prompts for instructions and language
(defun gptai-code-query (gptai-instructions gptai-language)
  "Sends instructions to OpenAI API to code in a language.
Argument GPTAI-INSTRUCTIONS code instructions for query.
Argument GPTAI-LANGUAGE language to generate."
  (interactive
   (list (read-string "Instructions: ")
         (read-string "Language: ")))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "%s(%s)" gptai-instructions gptai-language))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text)))))

;; explains code from selection text
(defun gptai-explain-code-from-selection ()
  "Sends selection code to OpenAI API to explain."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Code: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "Explain the following: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (insert text)
          (insert "\n\n"))))))

;; help document code from selection text
(defun gptai-document-code-from-selection ()
  "Sends selection code to OpenAI API to write documentation."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Code: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "Please write the documentation for the following code: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (insert text)
          (insert "\n\n"))))))

;; optimizes code from selection text
(defun gptai-optimize-code-from-selection ()
  "Sends selection code to OpenAI API to optimize."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Code: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "Optimize and refactor the following code: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text))))))


;; improve code from selection text
(defun gptai-improve-code-from-selection ()
  "Sends selection code to OpenAI API to improve."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Code: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "Improve and extend the following code: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text))))))

;; fix code from selection text
(defun gptai-fix-code-from-selection ()
  "Sends selected code to OpenAI API to fix a bug."
  (interactive)
  (let ((gptai-prompt (if (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))
                  (read-string "Code: "))))
    (with-current-buffer (current-buffer)
      (let ((response (gptai-request (format "There is a bug in the following function, please help me fix it: %s" gptai-prompt))))
        (let ((text (cdr (assoc 'text (elt (cdr (assoc 'choices response)) 0)))))
          (delete-region (region-beginning) (region-end))
          (insert text))))))

(defun gptai-send-image-query (prompt n size filepath)
  "Sends a query to the OpenAI Image Generation API.
Argument PROMPT prompt to send.
Argument N number of images to generate.
Argument SIZE size of images.
Argument FILEPATH filepath to download to."
  (interactive
   (list (read-string "Prompt: ")
         (read-number "Number of images to generate: " 1)
         (read-string "Image size (e.g. 1024x1024): " "1024x1024")
         (read-directory-name "Enter output directory: " "~/Pictures")))
  (when (null gptai-api-key)
    (error "OpenAI API key is not set"))
  (let* ((url "https://api.openai.com/v1/images/generations")
         (url-request-method "POST")
         (url-request-extra-headers
          `(("Content-Type" . "application/json")
            ("Authorization" . ,(format "Bearer %s" gptai-api-key))))
         (url-request-data
          (json-encode `(("prompt" . ,prompt)
                         ("n" . ,n)
                         ("size" . ,size)))))
    (message "Sending request to OpenAI Image Generation API")
    (condition-case err
        (with-current-buffer
            (url-retrieve-synchronously url nil 'silent)
          (goto-char url-http-end-of-headers)
          (let ((response (json-read)))
            (when (assoc 'error response)
              (error (cdr (assoc 'message (cdr (assoc 'error response))))))
            (with-current-buffer (get-buffer-create "*openai*")
              (erase-buffer)
              (insert (format "Generated image URLs:\n"))
              (defvar gptai-image nil)
              (defvar gptai-indn n)
              (setq gptai-image (let ((gptai-indn (length (cdr (assoc 'data response))))
                    (urls '()))
                (dotimes (x gptai-indn)
                  (push (cdr (assoc 'url (elt (cdr (assoc 'data response)) x))) urls))
                (reverse urls)))
              (insert (format "%s\n"
                              (let ((gptai-indn (length (cdr (assoc 'data response))))
                                    (urls '()))
                                (dotimes (x gptai-indn)
                                  (push (cdr (assoc 'url (elt (cdr (assoc 'data response)) x))) urls))
                                (reverse urls)))))
            (switch-to-buffer-other-window (current-buffer)))
          (defvar gptai-index 0)
          (defvar gptai-images nil)
          (defvar gptai-image nil)
          (let ((gptai-images gptai-image))
              (dolist (gptai-image gptai-images)
                (async-shell-command (format "curl '%s' > %s/%s_%d.png" gptai-image filepath (format-time-string "%T") gptai-index))
                (sleep-for 2 500)
                (setq gptai-index (+ gptai-index 1))))
            (message "Finished downloading %d images to %s" n filepath))
      (error (error "Error while sending request to OpenAI Image Generation API: %s"
                    (error-message-string err))))))

;; list all currently available models from the list of current models at OpenAI
(defun gptai-list-models ()
  "Retrieves a list of currently available GPT-3 models from OpenAI."
  (interactive)
  (with-current-buffer (get-buffer-create "*gptai-models*")
    (erase-buffer)
    (async-shell-command (format "curl https://api.openai.com/v1/models \
    -H 'Authorization: Bearer %s'" gptai-api-key) "*gptai-models*" "*Messages*")
    (goto-char (point-min))
    (re-search-forward "^.*object.*$")
    (delete-region (point-min) (point))
    (pop-to-buffer (current-buffer))))

(provide 'gptai)
;;; gptai.el ends here

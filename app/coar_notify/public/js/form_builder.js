/**
 * COAR Notify Dashboard - Dynamic Form Builder
 *
 * This script handles dynamic form generation based on pattern schemas
 * loaded from the PatternRegistry API.
 */

(function() {
  'use strict';

  /**
   * FormBuilder class for dynamically generating form fields
   */
  class FormBuilder {
    constructor(containerSelector) {
      this.container = document.querySelector(containerSelector);
      this.currentSchema = null;
    }

    /**
     * Load pattern schema from API and build form fields
     */
    async loadPatternSchema(patternName) {
      if (!patternName) {
        this.clearFields();
        return;
      }

      try {
        const response = await fetch(`/coar/dashboard/api/patterns/${patternName}/schema`);

        if (!response.ok) {
          throw new Error(`Failed to load schema: ${response.statusText}`);
        }

        this.currentSchema = await response.json();
        this.buildFields();
      } catch (error) {
        console.error('Error loading pattern schema:', error);
        this.showError('Failed to load pattern fields. Please try again.');
      }
    }

    /**
     * Build form fields from schema
     */
    buildFields() {
      if (!this.container || !this.currentSchema) {
        return;
      }

      this.clearFields();

      const fields = this.currentSchema.fields || [];

      if (fields.length === 0) {
        return; // No additional fields needed for this pattern
      }

      // Create form section
      const section = document.createElement('div');
      section.className = 'form-section';
      section.innerHTML = '<h3>4. Pattern-Specific Information</h3>';

      fields.forEach(field => {
        const fieldElement = this.createField(field);
        if (fieldElement) {
          section.appendChild(fieldElement);
        }
      });

      this.container.appendChild(section);
    }

    /**
     * Create a form field based on field definition
     */
    createField(field) {
      const formGroup = document.createElement('div');
      formGroup.className = 'form-group';

      // Create label
      const label = document.createElement('label');
      label.setAttribute('for', field.name);
      label.textContent = this.formatLabel(field.name);

      if (field.required) {
        const requiredSpan = document.createElement('span');
        requiredSpan.className = 'required';
        requiredSpan.textContent = ' *';
        label.appendChild(requiredSpan);
      }

      formGroup.appendChild(label);

      // Create input based on type
      const input = this.createInput(field);
      formGroup.appendChild(input);

      // Add help text if available
      if (field.description) {
        const helpText = document.createElement('p');
        helpText.className = 'help-text';
        helpText.textContent = field.description;
        formGroup.appendChild(helpText);
      }

      return formGroup;
    }

    /**
     * Create appropriate input element based on field type
     */
    createInput(field) {
      let input;

      switch (field.type) {
        case 'text':
        case 'url':
        case 'email':
          input = document.createElement('input');
          input.type = field.type;
          input.name = field.name;
          input.id = field.name;
          if (field.placeholder) {
            input.placeholder = field.placeholder;
          }
          if (field.required) {
            input.required = true;
          }
          break;

        case 'textarea':
          input = document.createElement('textarea');
          input.name = field.name;
          input.id = field.name;
          input.rows = field.rows || 3;
          if (field.placeholder) {
            input.placeholder = field.placeholder;
          }
          if (field.required) {
            input.required = true;
          }
          break;

        case 'select':
          input = document.createElement('select');
          input.name = field.name;
          input.id = field.name;
          if (field.required) {
            input.required = true;
          }

          // Add empty option
          const emptyOption = document.createElement('option');
          emptyOption.value = '';
          emptyOption.textContent = `-- Select ${this.formatLabel(field.name)} --`;
          input.appendChild(emptyOption);

          // Add options
          if (field.options && Array.isArray(field.options)) {
            field.options.forEach(option => {
              const optionElement = document.createElement('option');
              optionElement.value = option.value || option;
              optionElement.textContent = option.label || option;
              input.appendChild(optionElement);
            });
          }
          break;

        case 'date':
          input = document.createElement('input');
          input.type = 'date';
          input.name = field.name;
          input.id = field.name;
          if (field.required) {
            input.required = true;
          }
          break;

        case 'number':
          input = document.createElement('input');
          input.type = 'number';
          input.name = field.name;
          input.id = field.name;
          if (field.min !== undefined) {
            input.min = field.min;
          }
          if (field.max !== undefined) {
            input.max = field.max;
          }
          if (field.required) {
            input.required = true;
          }
          break;

        default:
          input = document.createElement('input');
          input.type = 'text';
          input.name = field.name;
          input.id = field.name;
          if (field.required) {
            input.required = true;
          }
      }

      return input;
    }

    /**
     * Format field name to readable label
     */
    formatLabel(name) {
      return name
        .replace(/_/g, ' ')
        .replace(/\b\w/g, l => l.toUpperCase());
    }

    /**
     * Clear all dynamically generated fields
     */
    clearFields() {
      if (this.container) {
        this.container.innerHTML = '';
      }
      this.currentSchema = null;
    }

    /**
     * Show error message
     */
    showError(message) {
      if (!this.container) {
        return;
      }

      this.clearFields();

      const errorDiv = document.createElement('div');
      errorDiv.className = 'alert alert-error';
      errorDiv.textContent = message;
      this.container.appendChild(errorDiv);
    }
  }

  /**
   * Initialize form builder when DOM is ready
   */
  function initFormBuilder() {
    const patternSelect = document.getElementById('pattern');
    const containerSelector = '#pattern-specific-fields';

    if (!patternSelect) {
      return; // Not on send notification page
    }

    const formBuilder = new FormBuilder(containerSelector);

    // Listen for pattern changes
    patternSelect.addEventListener('change', function() {
      const selectedPattern = this.value;

      if (selectedPattern) {
        formBuilder.loadPatternSchema(selectedPattern);
      } else {
        formBuilder.clearFields();
      }
    });
  }

  /**
   * Paper data loader for populating form with paper information
   */
  class PaperDataLoader {
    constructor() {
      this.issueSelect = document.getElementById('issue_id');
      this.currentPaper = null;

      if (this.issueSelect) {
        this.issueSelect.addEventListener('change', () => this.loadPaperData());
      }
    }

    async loadPaperData() {
      const issueId = this.issueSelect.value;

      if (!issueId) {
        this.currentPaper = null;
        return;
      }

      try {
        const response = await fetch(`/coar/dashboard/api/papers/${issueId}`);

        if (!response.ok) {
          throw new Error(`Failed to load paper data: ${response.statusText}`);
        }

        this.currentPaper = await response.json();
        this.populateFields();
      } catch (error) {
        console.error('Error loading paper data:', error);
        alert('Failed to load paper information. Please try again.');
      }
    }

    populateFields() {
      if (!this.currentPaper) {
        return;
      }

      // Auto-populate any matching fields in the form
      // This is useful for pre-filling data from the selected paper

      const fieldMappings = {
        'paper_doi': 'doi',
        'paper_title': 'title',
        'repository_url': 'repository_url',
        'editor_orcid': 'editor_orcid',
        'editor_name': 'editor_name'
      };

      Object.entries(fieldMappings).forEach(([fieldName, paperProperty]) => {
        const field = document.getElementById(fieldName) || document.querySelector(`[name="${fieldName}"]`);
        if (field && this.currentPaper[paperProperty]) {
          field.value = this.currentPaper[paperProperty];
        }
      });
    }

    getPaperData() {
      return this.currentPaper;
    }
  }

  /**
   * Form validation helper
   */
  class FormValidator {
    constructor(formSelector) {
      this.form = document.querySelector(formSelector);

      if (this.form) {
        this.form.addEventListener('submit', (e) => this.validate(e));
      }
    }

    validate(event) {
      // Check if UndoOffer is selected and validate accordingly
      const patternSelect = document.getElementById('pattern');

      if (patternSelect && patternSelect.value === 'UndoOffer') {
        const originalNotificationId = document.getElementById('original_notification_id');

        if (!originalNotificationId || !originalNotificationId.value) {
          event.preventDefault();
          alert('Please select the notification you want to withdraw.');
          if (originalNotificationId) {
            originalNotificationId.focus();
          }
          return false;
        }
      }

      // Additional custom validation can be added here
      return true;
    }
  }

  /**
   * Utility functions
   */
  const Utils = {
    /**
     * Show loading state
     */
    showLoading(element, message = 'Loading...') {
      if (element) {
        element.innerHTML = `<div class="loading">${message}</div>`;
      }
    },

    /**
     * Format date for display
     */
    formatDate(dateString) {
      const date = new Date(dateString);
      return date.toLocaleString();
    },

    /**
     * Debounce function for performance
     */
    debounce(func, wait) {
      let timeout;
      return function executedFunction(...args) {
        const later = () => {
          clearTimeout(timeout);
          func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
      };
    }
  };

  /**
   * Initialize all components when DOM is ready
   */
  document.addEventListener('DOMContentLoaded', function() {
    initFormBuilder();

    // Initialize paper data loader
    if (document.getElementById('issue_id')) {
      window.paperDataLoader = new PaperDataLoader();
    }

    // Initialize form validator
    if (document.getElementById('send-notification-form')) {
      window.formValidator = new FormValidator('#send-notification-form');
    }

    // Auto-submit filter forms on change (for better UX)
    const filterSelects = document.querySelectorAll('.filters-form select');
    filterSelects.forEach(select => {
      select.addEventListener('change', function() {
        this.form.submit();
      });
    });
  });

  // Export utilities for use in inline scripts
  window.CoarNotify = {
    FormBuilder,
    PaperDataLoader,
    FormValidator,
    Utils
  };

})();

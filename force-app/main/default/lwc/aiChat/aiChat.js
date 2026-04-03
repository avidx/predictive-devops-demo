import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AiChat extends LightningElement {
    @api title = 'AI Assistant';
    @api placeholder = 'Ask me anything...';
    @api maxTokens = 1000;
    @api temperature = 0.7;
    
    @track messages = [];
    @track currentInput = '';
    @track isLoading = false;
    @track error = null;

    connectedCallback() {
        // Add welcome message
        this.addMessage('assistant', 'Hello! I\'m your AI assistant. How can I help you today?');
    }

    handleInputChange(event) {
        this.currentInput = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendMessage();
        }
    }

    sendMessage() {
        if (!this.currentInput.trim()) return;

        const userMessage = this.currentInput.trim();
        this.addMessage('user', userMessage);
        this.currentInput = '';
        this.isLoading = true;

        // Simulate AI response with immediate response
        const response = this.getFallbackResponse(userMessage);
        this.addMessage('assistant', response);
        this.isLoading = false;
    }

    getFallbackResponse(userMessage) {
        const lowerMessage = userMessage.toLowerCase();
        
        // Check for specific keywords
        if (lowerMessage.includes('hello') || lowerMessage.includes('hi')) {
            return 'Hello! How can I help you today?';
        }
        if (lowerMessage.includes('help')) {
            return 'I can help you with various tasks. Just ask me anything!';
        }
        if (lowerMessage.includes('weather')) {
            return 'I can help you check the weather. Please provide a location.';
        }
        if (lowerMessage.includes('joke')) {
            return 'Why don\'t scientists trust atoms? Because they make up everything! 😄';
        }
        if (lowerMessage.includes('quote')) {
            return 'The only way to do great work is to love what you do. - Steve Jobs';
        }
        
        // Generate contextual response
        return this.generateContextualResponse(userMessage);
    }

    generateContextualResponse(userMessage) {
        const responses = [
            'That\'s an interesting question! Let me think about that.',
            'I understand what you\'re asking. Here\'s what I can tell you...',
            'Great question! Based on what I know, here\'s my response...',
            'I appreciate your question. Let me provide some insights...',
            'That\'s a thoughtful inquiry. Here\'s my perspective...'
        ];
        
        // Use the message length to select a response (simple algorithm)
        const index = userMessage.length % responses.length;
        return responses[index];
    }

    addMessage(role, content) {
        const message = {
            id: Date.now(),
            role: role,
            content: content,
            timestamp: new Date().toLocaleTimeString(),
            isUser: role === 'user'
        };
        
        this.messages = [...this.messages, message];
        
        // Auto-scroll to bottom after DOM update
        this.scrollToBottom();
    }

    scrollToBottom() {
        const chatContainer = this.template.querySelector('.chat-messages');
        if (chatContainer) {
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }
    }

    clearChat() {
        this.messages = [];
        this.addMessage('assistant', 'Chat cleared! How can I help you?');
    }

    copyToClipboard(event) {
        const messageContent = event.currentTarget.dataset.message;
        navigator.clipboard.writeText(messageContent).then(() => {
            this.showToast('Success', 'Text copied to clipboard!', 'success');
        }).catch(() => {
            this.showToast('Error', 'Failed to copy text', 'error');
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasMessages() {
        return this.messages.length > 0;
    }

    get messageCount() {
        return this.messages.length;
    }
}
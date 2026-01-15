<?php

namespace App\Http\Requests\Commerce;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Listing Store Request
 * 
 * Validation for creating a new listing.
 */
final class ListingStoreRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        // Authorization handled by middleware (auth.any + tenant.user)
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     */
    public function rules(): array
    {
        return [
            'title' => 'required|string|max:120',
            'description' => 'nullable|string|max:5000',
            'price_amount' => 'required|numeric|min:0',
            'currency' => 'required|string|size:3',
        ];
    }
}





